// Reference resolution utilities

import errors.{type ValidationError}
import gleam/dict.{type Dict}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import honk/internal/json_helpers
import validation/context.{type ValidationContext}

/// Resolves a reference string to its target definition
pub fn resolve_reference(
  reference: String,
  ctx: ValidationContext,
  current_lexicon_id: String,
) -> Result(Option(Json), ValidationError) {
  // Update context with current lexicon
  let ctx = context.with_current_lexicon(ctx, current_lexicon_id)

  // Parse the reference
  case context.parse_reference(ctx, reference) {
    Ok(#(lex_id, def_name)) -> {
      // Get the lexicon
      case context.get_lexicon(ctx, lex_id) {
        Some(lexicon) -> {
          // Navigate to the specific definition in defs object
          case json_helpers.get_field(lexicon.defs, def_name) {
            Some(def_schema) -> Ok(Some(def_schema))
            None ->
              Error(errors.invalid_schema(
                "Definition '"
                <> def_name
                <> "' not found in lexicon '"
                <> lex_id
                <> "'",
              ))
          }
        }
        None ->
          Error(errors.invalid_schema(
            "Referenced lexicon not found: " <> lex_id,
          ))
      }
    }
    Error(e) -> Error(e)
  }
}

/// Validates that a reference exists and is accessible
pub fn validate_reference(
  reference: String,
  ctx: ValidationContext,
  current_lexicon_id: String,
  def_path: String,
) -> Result(Nil, ValidationError) {
  // Check for circular reference
  case context.has_reference(ctx, reference) {
    True ->
      Error(errors.invalid_schema(
        def_path <> ": Circular reference detected: " <> reference,
      ))
    False -> {
      // Try to resolve the reference
      case resolve_reference(reference, ctx, current_lexicon_id) {
        Ok(Some(_)) -> Ok(Nil)
        Ok(None) ->
          Error(errors.invalid_schema(
            def_path <> ": Reference not found: " <> reference,
          ))
        Error(e) -> Error(e)
      }
    }
  }
}

/// Collects all references from a definition recursively
/// Traverses JSON structure looking for "ref" fields
fn collect_references_recursive(
  value: Json,
  references: Set(String),
) -> Set(String) {
  // Check if this is an object with a "ref" field
  let refs = case json_helpers.get_string(value, "ref") {
    Some(ref_str) -> set.insert(references, ref_str)
    None -> references
  }

  // If it's an object, recursively check all its values
  case json_helpers.json_to_dict(value) {
    Ok(dict_value) -> {
      dict.fold(dict_value, refs, fn(acc, _key, field_value) {
        case json_helpers.dynamic_to_json(field_value) {
          Ok(field_json) -> collect_references_recursive(field_json, acc)
          Error(_) -> acc
        }
      })
    }
    Error(_) -> {
      // If it's an array, check each element
      case json_helpers.get_array_from_value(value) {
        Some(array_items) -> {
          list.fold(array_items, refs, fn(acc, item) {
            case json_helpers.dynamic_to_json(item) {
              Ok(item_json) -> collect_references_recursive(item_json, acc)
              Error(_) -> acc
            }
          })
        }
        None -> refs
      }
    }
  }
}

/// Validates all references in a lexicon are resolvable
pub fn validate_lexicon_references(
  lexicon_id: String,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  case context.get_lexicon(ctx, lexicon_id) {
    Some(lexicon) -> {
      // Collect all references from the lexicon
      let references = collect_references_recursive(lexicon.defs, set.new())

      // Validate each reference
      set.fold(references, Ok(Nil), fn(acc, reference) {
        case acc {
          Error(e) -> Error(e)
          Ok(_) -> validate_reference(reference, ctx, lexicon_id, lexicon_id)
        }
      })
    }
    None ->
      Error(errors.lexicon_not_found(
        "Lexicon not found for validation: " <> lexicon_id,
      ))
  }
}

/// Validates completeness of all lexicons
pub fn validate_lexicon_completeness(
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  // Get all lexicon IDs
  let lexicon_ids = dict.keys(ctx.lexicons)

  // Validate references for each lexicon
  list.try_fold(lexicon_ids, Nil, fn(_, lex_id) {
    validate_lexicon_references(lex_id, ctx)
  })
}

/// Detects circular dependencies in lexicon references
pub fn detect_circular_dependencies(
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  // Build dependency graph
  let graph = build_dependency_graph(ctx)

  // Check for cycles using DFS
  let lexicon_ids = dict.keys(ctx.lexicons)
  let visited = set.new()
  let rec_stack = set.new()

  list.try_fold(lexicon_ids, #(visited, rec_stack), fn(state, node) {
    let #(visited, rec_stack) = state
    case set.contains(visited, node) {
      True -> Ok(state)
      False -> {
        case has_cycle_dfs(node, graph, visited, rec_stack) {
          #(True, _v, _r) ->
            Error(errors.invalid_schema(
              "Circular dependency detected involving: " <> node,
            ))
          #(False, v, r) -> Ok(#(v, r))
        }
      }
    }
  })
  |> result.map(fn(_) { Nil })
}

/// Build a dependency graph from lexicon references
fn build_dependency_graph(ctx: ValidationContext) -> Dict(String, Set(String)) {
  dict.fold(ctx.lexicons, dict.new(), fn(graph, lex_id, lexicon) {
    let refs = collect_references_recursive(lexicon.defs, set.new())
    // Extract just the lexicon IDs from references (before the #)
    let dep_lexicons =
      set.fold(refs, set.new(), fn(acc, reference) {
        case string.split(reference, "#") {
          [nsid, _] if nsid != "" -> set.insert(acc, nsid)
          [nsid] if nsid != "" -> set.insert(acc, nsid)
          _ -> acc
        }
      })
    dict.insert(graph, lex_id, dep_lexicons)
  })
}

/// Helper for cycle detection using DFS
fn has_cycle_dfs(
  node: String,
  graph: Dict(String, Set(String)),
  visited: Set(String),
  rec_stack: Set(String),
) -> #(Bool, Set(String), Set(String)) {
  let visited = set.insert(visited, node)
  let rec_stack = set.insert(rec_stack, node)

  // Get neighbors
  let neighbors = case dict.get(graph, node) {
    Ok(deps) -> deps
    Error(_) -> set.new()
  }

  // Check each neighbor
  let result =
    set.fold(neighbors, #(False, visited, rec_stack), fn(state, neighbor) {
      let #(has_cycle, v, r) = state
      case has_cycle {
        True -> state
        False -> {
          case set.contains(v, neighbor) {
            False -> has_cycle_dfs(neighbor, graph, v, r)
            True ->
              case set.contains(r, neighbor) {
                True -> #(True, v, r)
                False -> state
              }
          }
        }
      }
    })

  // Remove from recursion stack
  let #(has_cycle, v, r) = result
  #(has_cycle, v, set.delete(r, node))
}
