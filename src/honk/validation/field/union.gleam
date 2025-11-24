// Union type validator

import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import honk/errors
import honk/internal/constraints
import honk/internal/json_helpers
import honk/internal/resolution
import honk/validation/context.{type ValidationContext}

const allowed_fields = ["type", "refs", "closed", "description"]

/// Validates union schema definition
pub fn validate_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Validate allowed fields
  let keys = json_helpers.get_keys(schema)
  use _ <- result.try(constraints.validate_allowed_fields(
    def_name,
    keys,
    allowed_fields,
    "union",
  ))

  // Validate refs field (required)
  let refs = case json_helpers.get_array(schema, "refs") {
    Some(refs_array) -> Ok(refs_array)
    None ->
      Error(errors.invalid_schema(
        def_name <> ": union missing required 'refs' field",
      ))
  }

  use refs_array <- result.try(refs)

  // Validate that all refs are strings
  use _ <- result.try(
    list.index_fold(refs_array, Ok(Nil), fn(acc, ref_item, i) {
      use _ <- result.try(acc)
      case decode.run(ref_item, decode.string) {
        Ok(_) -> Ok(Nil)
        Error(_) ->
          Error(errors.invalid_schema(
            def_name <> ": refs[" <> string.inspect(i) <> "] must be a string",
          ))
      }
    }),
  )

  // Validate closed field if present
  use _ <- result.try(case json_helpers.get_bool(schema, "closed") {
    Some(closed) -> {
      // If closed is true and refs is empty, that's invalid
      case closed && list.is_empty(refs_array) {
        True ->
          Error(errors.invalid_schema(
            def_name <> ": union cannot be closed with empty refs array",
          ))
        False -> Ok(Nil)
      }
    }
    None -> Ok(Nil)
  })

  // Empty refs array is only allowed for open unions
  use _ <- result.try(case list.is_empty(refs_array) {
    True -> {
      case json_helpers.get_bool(schema, "closed") {
        Some(True) ->
          Error(errors.invalid_schema(
            def_name <> ": union cannot have empty refs array when closed=true",
          ))
        _ -> Ok(Nil)
      }
    }
    False -> Ok(Nil)
  })

  // Validate that each reference can be resolved
  validate_refs_resolvable(refs_array, ctx, def_name)
}

/// Validates that all references in the refs array can be resolved
fn validate_refs_resolvable(
  refs_array: List(decode.Dynamic),
  ctx: ValidationContext,
  def_name: String,
) -> Result(Nil, errors.ValidationError) {
  // Convert refs to strings
  let ref_strings =
    list.filter_map(refs_array, fn(r) { decode.run(r, decode.string) })

  // Check each reference can be resolved (both local and global refs)
  list.try_fold(ref_strings, Nil, fn(_, ref_str) {
    case context.current_lexicon_id(ctx) {
      Some(lex_id) -> {
        // We have a full validation context, so validate reference resolution
        // This works for both local refs (#def) and global refs (nsid#def)
        use resolved <- result.try(resolution.resolve_reference(
          ref_str,
          ctx,
          lex_id,
        ))

        case resolved {
          Some(_) -> Ok(Nil)
          None ->
            Error(errors.invalid_schema(
              def_name <> ": reference not found: " <> ref_str,
            ))
        }
      }
      None -> {
        // No current lexicon (e.g., unit test context)
        // Just validate syntax, can't check if reference exists
        Ok(Nil)
      }
    }
  })
}

/// Validates union data against schema
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Union data must be an object
  case json_helpers.is_object(data) {
    False -> {
      let type_name = get_type_name(data)
      Error(errors.data_validation(
        def_name
        <> ": union data must be an object which includes the \"$type\" property, found "
        <> type_name,
      ))
    }
    True -> {
      // Check for $type discriminator field
      let type_field = case json_helpers.get_string(data, "$type") {
        Some(type_name) -> Ok(type_name)
        None ->
          Error(errors.data_validation(
            def_name
            <> ": union data must be an object which includes the \"$type\" property",
          ))
      }

      use type_name <- result.try(type_field)

      // Get the union's referenced types
      let refs = case json_helpers.get_array(schema, "refs") {
        Some(refs_array) -> Ok(refs_array)
        None ->
          Error(errors.data_validation(
            def_name <> ": union schema missing or invalid 'refs' field",
          ))
      }

      use refs_array <- result.try(refs)

      case list.is_empty(refs_array) {
        True ->
          Error(errors.data_validation(
            def_name <> ": union schema has empty refs array",
          ))
        False -> {
          // Convert refs to strings
          let ref_strings =
            list.filter_map(refs_array, fn(r) { decode.run(r, decode.string) })

          // Check if the $type matches any of the refs
          case
            list.find(ref_strings, fn(ref_str) {
              refs_contain_type(ref_str, type_name)
            })
          {
            Ok(matching_ref) -> {
              // Found matching ref - validate data against the resolved schema
              validate_against_resolved_ref(data, matching_ref, ctx, def_name)
            }
            Error(Nil) -> {
              // No matching ref found
              // Check if union is closed
              let is_closed = case json_helpers.get_bool(schema, "closed") {
                Some(closed) -> closed
                None -> False
              }

              case is_closed {
                True -> {
                  // Closed union - reject unknown types
                  Error(errors.data_validation(
                    def_name
                    <> ": union data $type must be one of "
                    <> string.join(ref_strings, ", ")
                    <> ", found '"
                    <> type_name
                    <> "'",
                  ))
                }
                False -> {
                  // Open union - allow unknown types
                  Ok(Nil)
                }
              }
            }
          }
        }
      }
    }
  }
}

/// Validates data against a resolved reference from the union
fn validate_against_resolved_ref(
  data: Json,
  ref_str: String,
  ctx: ValidationContext,
  def_name: String,
) -> Result(Nil, errors.ValidationError) {
  // Get current lexicon ID to resolve the reference
  case context.current_lexicon_id(ctx) {
    Some(lex_id) -> {
      // We have a validation context, try to resolve and validate
      use resolved_opt <- result.try(resolution.resolve_reference(
        ref_str,
        ctx,
        lex_id,
      ))

      case resolved_opt {
        Some(resolved_schema) -> {
          // Successfully resolved - validate data against the resolved schema
          let validator = ctx.validator
          validator(data, resolved_schema, ctx)
        }
        None -> {
          // Reference couldn't be resolved
          // This shouldn't happen as schema validation should have caught it,
          // but handle gracefully
          Error(errors.data_validation(
            def_name <> ": reference not found: " <> ref_str,
          ))
        }
      }
    }
    None -> {
      // No lexicon context (e.g., unit test)
      // Can't validate against resolved schema, just accept the data
      Ok(Nil)
    }
  }
}

/// Checks if refs array contains the given type
/// Based on AT Protocol's refsContainType logic - handles both explicit and implicit #main
fn refs_contain_type(reference: String, type_name: String) -> Bool {
  // Direct match
  case reference == type_name {
    True -> True
    False -> {
      // Handle local reference patterns (#ref)
      case string.starts_with(reference, "#") {
        True -> {
          let ref_name = string.drop_start(reference, 1)
          // Match bare name against local ref
          case type_name == ref_name {
            True -> True
            False -> {
              // Match full NSID#fragment against local ref
              string.ends_with(type_name, "#" <> ref_name)
            }
          }
        }
        False -> {
          // Handle implicit #main patterns
          case string.ends_with(type_name, "#main") {
            True -> {
              // Remove "#main"
              let base_type = string.drop_end(type_name, 5)
              reference == base_type
            }
            False -> {
              // type_name has no fragment, check if ref is the #main version
              case string.contains(type_name, "#") {
                True -> False
                False -> {
                  let main_ref = type_name <> "#main"
                  reference == main_ref
                }
              }
            }
          }
        }
      }
    }
  }
}

/// Helper to get type name for error messages
fn get_type_name(data: Json) -> String {
  case json_helpers.is_null(data) {
    True -> "null"
    False ->
      case json_helpers.is_bool(data) {
        True -> "boolean"
        False ->
          case json_helpers.is_int(data) {
            True -> "number"
            False ->
              case json_helpers.is_string(data) {
                True -> "string"
                False ->
                  case json_helpers.is_array(data) {
                    True -> "array"
                    False ->
                      case json_helpers.is_object(data) {
                        True -> "object"
                        False -> "unknown"
                      }
                  }
              }
          }
      }
  }
}
