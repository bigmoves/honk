// Token type validator
// Tokens are unit types used for discrimination in unions

import honk/errors as errors
import gleam/json.{type Json}
import gleam/string
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}

const allowed_fields = ["type", "description"]

/// Validates token schema definition
pub fn validate_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Validate allowed fields
  let keys = json_helpers.get_keys(schema)
  constraints.validate_allowed_fields(def_name, keys, allowed_fields, "token")
}

/// Validates token data against schema
/// Note: Tokens are unit types used for discrimination in unions.
/// The token value should be a string matching the fully-qualified token name
/// (e.g., "example.lexicon.record#demoToken"). Full token name validation
/// happens at the union/record level where the expected token name is known.
pub fn validate_data(
  data: Json,
  _schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Token data must be a string (the fully-qualified token name)
  case json_helpers.is_string(data) {
    True -> {
      // Extract and validate the string value
      let json_str = json.to_string(data)
      // Remove quotes from JSON string representation
      let value = case
        string.starts_with(json_str, "\"") && string.ends_with(json_str, "\"")
      {
        True -> string.slice(json_str, 1, string.length(json_str) - 2)
        False -> json_str
      }

      case string.is_empty(value) {
        True ->
          Error(errors.data_validation(
            def_name <> ": token value cannot be empty string",
          ))
        False -> Ok(Nil)
      }
    }
    False ->
      Error(errors.data_validation(
        def_name <> ": expected string for token data, got other type",
      ))
  }
}
