// Unknown type validator
// Unknown allows flexible data with AT Protocol data model rules

import gleam/json.{type Json}
import gleam/option.{None, Some}
import honk/errors
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}

const allowed_fields = ["type", "description"]

/// Validates unknown schema definition
pub fn validate_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Validate allowed fields
  let keys = json_helpers.get_keys(schema)
  constraints.validate_allowed_fields(def_name, keys, allowed_fields, "unknown")
}

/// Validates unknown data against schema
/// Unknown allows flexible data following AT Protocol data model rules
pub fn validate_data(
  data: Json,
  _schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Unknown data must be an object (not primitives, arrays, bytes, or blobs)
  case json_helpers.is_object(data) {
    False ->
      Error(errors.data_validation(
        def_name <> ": unknown type must be an object, not a primitive or array",
      ))
    True -> {
      // Check for special AT Protocol objects that are not allowed
      // Bytes objects: {"$bytes": "base64-string"}
      case json_helpers.get_string(data, "$bytes") {
        Some(_) ->
          Error(errors.data_validation(
            def_name <> ": unknown type cannot be a bytes object",
          ))
        None -> {
          // Blob objects: {"$type": "blob", "ref": {...}, "mimeType": "...", "size": ...}
          case json_helpers.get_string(data, "$type") {
            Some("blob") ->
              Error(errors.data_validation(
                def_name <> ": unknown type cannot be a blob object",
              ))
            _ -> {
              // Valid unknown object
              // AT Protocol data model rules:
              // - No floats (only integers) - enforced by gleam_json type system
              // - Objects can contain any valid JSON data
              // - May contain $type field for type discrimination
              Ok(Nil)
            }
          }
        }
      }
    }
  }
}
