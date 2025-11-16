// Null type validator

import errors.{type ValidationError}
import gleam/json.{type Json}
import honk/internal/constraints
import honk/internal/json_helpers
import validation/context.{type ValidationContext}

const allowed_fields = ["type", "description"]

/// Validates null schema definition
pub fn validate_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Validate allowed fields
  let keys = json_helpers.get_keys(schema)
  constraints.validate_allowed_fields(def_name, keys, allowed_fields, "null")
}

/// Validates null data against schema
pub fn validate_data(
  data: Json,
  _schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Check data is null
  case json_helpers.is_null(data) {
    True -> Ok(Nil)
    False ->
      Error(errors.data_validation(
        def_name <> ": expected null, got other type",
      ))
  }
}
