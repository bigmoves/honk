// Boolean type validator

import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleam/result
import honk/errors
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}

const allowed_fields = ["type", "const", "default", "description"]

/// Validates boolean schema definition
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
    "boolean",
  ))

  // Validate const/default exclusivity
  let has_const = json_helpers.get_bool(schema, "const") != None
  let has_default = json_helpers.get_bool(schema, "default") != None

  constraints.validate_const_default_exclusivity(
    def_name,
    has_const,
    has_default,
    "boolean",
  )
}

/// Validates boolean data against schema
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Check data is a boolean
  case json_helpers.is_bool(data) {
    False ->
      Error(errors.data_validation(
        def_name <> ": expected boolean, got other type",
      ))
    True -> {
      // Extract boolean value
      let json_str = json.to_string(data)
      let is_true = json_str == "true"
      let is_false = json_str == "false"

      case is_true || is_false {
        False ->
          Error(errors.data_validation(
            def_name <> ": invalid boolean representation",
          ))
        True -> {
          let value = is_true

          // Validate const constraint
          case json_helpers.get_bool(schema, "const") {
            Some(const_val) if const_val != value ->
              Error(errors.data_validation(
                def_name
                <> ": must be constant value "
                <> case const_val {
                  True -> "true"
                  False -> "false"
                },
              ))
            _ -> Ok(Nil)
          }
        }
      }
    }
  }
}
