// Bytes type validator
// Bytes are base64-encoded strings

import gleam/bit_array
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import honk/errors
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}

const allowed_fields = ["type", "minLength", "maxLength", "description"]

/// Validates bytes schema definition
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
    "bytes",
  ))

  // Validate length constraints
  let min_length = json_helpers.get_int(schema, "minLength")
  let max_length = json_helpers.get_int(schema, "maxLength")

  // Check for negative values
  use _ <- result.try(case min_length {
    Some(min) if min < 0 ->
      Error(errors.invalid_schema(
        def_name <> ": bytes schema minLength below zero",
      ))
    _ -> Ok(Nil)
  })

  use _ <- result.try(case max_length {
    Some(max) if max < 0 ->
      Error(errors.invalid_schema(
        def_name <> ": bytes schema maxLength below zero",
      ))
    _ -> Ok(Nil)
  })

  constraints.validate_length_constraint_consistency(
    def_name,
    min_length,
    max_length,
    "bytes",
  )
}

/// Validates bytes data against schema
/// Expects data in ATProto format: {"$bytes": "base64-string"}
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Check data is an object
  case json_helpers.is_object(data) {
    False -> Error(errors.data_validation(def_name <> ": expecting bytes"))
    True -> {
      // Get all keys from the object
      let keys = json_helpers.get_keys(data)

      // Must have exactly one field
      use _ <- result.try(case list.length(keys) {
        1 -> Ok(Nil)
        _ ->
          Error(errors.data_validation(
            def_name <> ": $bytes objects must have a single field",
          ))
      })

      // That field must be "$bytes" with a string value
      case json_helpers.get_string(data, "$bytes") {
        None ->
          Error(errors.data_validation(
            def_name <> ": $bytes field missing or not a string",
          ))
        Some(base64_str) -> {
          // Decode the base64 string (using RawStdEncoding - no padding)
          case bit_array.base64_decode(base64_str) {
            Error(_) ->
              Error(errors.data_validation(
                def_name <> ": decoding $bytes value: invalid base64 encoding",
              ))
            Ok(decoded_bytes) -> {
              // Validate length of decoded bytes
              let byte_length = bit_array.byte_size(decoded_bytes)
              let min_length = json_helpers.get_int(schema, "minLength")
              let max_length = json_helpers.get_int(schema, "maxLength")

              // Check length constraints
              use _ <- result.try(case min_length {
                Some(min) if byte_length < min ->
                  Error(errors.data_validation(
                    def_name
                    <> ": bytes size out of bounds: "
                    <> string.inspect(byte_length),
                  ))
                _ -> Ok(Nil)
              })

              use _ <- result.try(case max_length {
                Some(max) if byte_length > max ->
                  Error(errors.data_validation(
                    def_name
                    <> ": bytes size out of bounds: "
                    <> string.inspect(byte_length),
                  ))
                _ -> Ok(Nil)
              })

              Ok(Nil)
            }
          }
        }
      }
    }
  }
}
