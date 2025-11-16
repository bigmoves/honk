// CID Link type validator
// CID links are IPFS content identifiers

import honk/errors as errors
import gleam/json.{type Json}
import gleam/option
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}
import honk/validation/formats

const allowed_fields = ["type", "description"]

/// Validates cid-link schema definition
pub fn validate_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Validate allowed fields
  let keys = json_helpers.get_keys(schema)
  constraints.validate_allowed_fields(
    def_name,
    keys,
    allowed_fields,
    "cid-link",
  )
}

/// Validates cid-link data against schema
pub fn validate_data(
  data: Json,
  _schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Check data is an object with $link field
  case json_helpers.is_object(data) {
    False ->
      Error(errors.data_validation(def_name <> ": expected CID link object"))
    True -> {
      // Validate structure: {$link: CID string}
      case json_helpers.get_string(data, "$link") {
        option.Some(cid) -> {
          // Validate CID format
          case formats.is_valid_cid(cid) {
            True -> Ok(Nil)
            False ->
              Error(errors.data_validation(
                def_name <> ": invalid CID format in $link",
              ))
          }
        }
        option.None ->
          Error(errors.data_validation(
            def_name <> ": CID link must have $link field",
          ))
      }
    }
  }
}
