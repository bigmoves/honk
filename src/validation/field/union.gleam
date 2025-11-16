// Union type validator

import errors.{type ValidationError}
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import json_helpers
import validation/constraints
import validation/context.{type ValidationContext}

const allowed_fields = ["type", "refs", "closed", "description"]

/// Validates union schema definition
pub fn validate_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
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
  case list.is_empty(refs_array) {
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
  }
  // Note: Full implementation would validate that each reference can be resolved
}

/// Validates union data against schema
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
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
            Ok(_matching_ref) -> {
              // Found matching ref
              // In full implementation, would validate against the resolved schema
              Ok(Nil)
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
