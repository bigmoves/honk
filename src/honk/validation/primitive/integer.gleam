// Integer type validator

import gleam/dynamic/decode
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import honk/errors
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}

const allowed_fields = [
  "type", "minimum", "maximum", "enum", "const", "default", "description",
]

/// Validates integer schema definition
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
    "integer",
  ))

  // Extract min/max constraints
  let minimum = json_helpers.get_int(schema, "minimum")
  let maximum = json_helpers.get_int(schema, "maximum")

  // Validate constraint consistency
  use _ <- result.try(constraints.validate_integer_constraint_consistency(
    def_name,
    minimum,
    maximum,
  ))

  // Validate enum is array of integers if present
  use _ <- result.try(case json_helpers.get_array(schema, "enum") {
    Some(enum_array) -> {
      list.try_fold(enum_array, Nil, fn(_, item) {
        case decode.run(item, decode.int) {
          Ok(_) -> Ok(Nil)
          Error(_) ->
            Error(errors.invalid_schema(
              def_name <> ": enum values must be integers",
            ))
        }
      })
    }
    None -> Ok(Nil)
  })

  // Validate const/default exclusivity
  let has_const = json_helpers.get_int(schema, "const") != None
  let has_default = json_helpers.get_int(schema, "default") != None

  constraints.validate_const_default_exclusivity(
    def_name,
    has_const,
    has_default,
    "integer",
  )
}

/// Validates integer data against schema
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Check data is an integer
  case json_helpers.is_int(data) {
    False ->
      Error(errors.data_validation(
        def_name <> ": expected integer, got other type",
      ))
    True -> {
      // Extract integer value
      let json_str = json.to_string(data)
      case int.parse(json_str) {
        Error(_) ->
          Error(errors.data_validation(
            def_name <> ": failed to parse integer value",
          ))
        Ok(value) -> {
          // Validate const constraint first (most restrictive)
          case json_helpers.get_int(schema, "const") {
            Some(const_val) if const_val != value ->
              Error(errors.data_validation(
                def_name
                <> ": must be constant value "
                <> int.to_string(const_val)
                <> ", found "
                <> int.to_string(value),
              ))
            Some(_) -> Ok(Nil)
            None -> {
              // Validate enum constraint
              use _ <- result.try(case json_helpers.get_array(schema, "enum") {
                Some(enum_array) -> {
                  let enum_ints =
                    list.filter_map(enum_array, fn(item) {
                      decode.run(item, decode.int)
                    })

                  validate_integer_enum(value, enum_ints, def_name)
                }
                None -> Ok(Nil)
              })

              // Validate range constraints
              let minimum = json_helpers.get_int(schema, "minimum")
              let maximum = json_helpers.get_int(schema, "maximum")

              constraints.validate_integer_range(
                def_name,
                value,
                minimum,
                maximum,
              )
            }
          }
        }
      }
    }
  }
}

/// Helper to validate integer enum
fn validate_integer_enum(
  value: Int,
  enum_values: List(Int),
  def_name: String,
) -> Result(Nil, errors.ValidationError) {
  constraints.validate_enum_constraint(
    def_name,
    value,
    enum_values,
    "integer",
    int.to_string,
    fn(a, b) { a == b },
  )
}
