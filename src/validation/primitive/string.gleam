// String type validator

import errors.{type ValidationError}
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import honk/internal/constraints
import honk/internal/json_helpers
import types
import validation/context.{type ValidationContext}
import validation/formats

const allowed_fields = [
  "type", "format", "minLength", "maxLength", "minGraphemes", "maxGraphemes",
  "enum", "knownValues", "const", "default", "description",
]

/// Validates string schema definition
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
    "string",
  ))

  // Validate format if present
  case json_helpers.get_string(schema, "format") {
    Some(format_str) ->
      case types.string_to_format(format_str) {
        Ok(_format) -> Ok(Nil)
        Error(_) ->
          Error(errors.invalid_schema(
            def_name
            <> ": unknown format '"
            <> format_str
            <> "'. Valid formats: datetime, uri, at-uri, did, handle, at-identifier, nsid, cid, language, tid, record-key",
          ))
      }
    None -> Ok(Nil)
  }
  |> result.try(fn(_) {
    // Extract length constraints
    let min_length = json_helpers.get_int(schema, "minLength")
    let max_length = json_helpers.get_int(schema, "maxLength")
    let min_graphemes = json_helpers.get_int(schema, "minGraphemes")
    let max_graphemes = json_helpers.get_int(schema, "maxGraphemes")

    // Check for negative values
    use _ <- result.try(case min_length {
      Some(n) if n < 0 ->
        Error(errors.invalid_schema(
          def_name <> ": string schema minLength below zero",
        ))
      _ -> Ok(Nil)
    })

    use _ <- result.try(case max_length {
      Some(n) if n < 0 ->
        Error(errors.invalid_schema(
          def_name <> ": string schema maxLength below zero",
        ))
      _ -> Ok(Nil)
    })

    use _ <- result.try(case min_graphemes {
      Some(n) if n < 0 ->
        Error(errors.invalid_schema(
          def_name <> ": string schema minGraphemes below zero",
        ))
      _ -> Ok(Nil)
    })

    use _ <- result.try(case max_graphemes {
      Some(n) if n < 0 ->
        Error(errors.invalid_schema(
          def_name <> ": string schema maxGraphemes below zero",
        ))
      _ -> Ok(Nil)
    })

    // Validate byte length constraints
    use _ <- result.try(constraints.validate_length_constraint_consistency(
      def_name,
      min_length,
      max_length,
      "string",
    ))

    // Validate grapheme constraints
    constraints.validate_length_constraint_consistency(
      def_name,
      min_graphemes,
      max_graphemes,
      "string (graphemes)",
    )
  })
  |> result.try(fn(_) {
    // Validate enum is array of strings if present
    case json_helpers.get_array(schema, "enum") {
      Some(enum_array) -> {
        // Check each item is a string
        list.try_fold(enum_array, Nil, fn(_, item) {
          case decode.run(item, decode.string) {
            Ok(_) -> Ok(Nil)
            Error(_) ->
              Error(errors.invalid_schema(
                def_name <> ": enum values must be strings",
              ))
          }
        })
      }
      None -> Ok(Nil)
    }
  })
  |> result.try(fn(_) {
    // Validate knownValues is array of strings if present
    case json_helpers.get_array(schema, "knownValues") {
      Some(known_array) -> {
        list.try_fold(known_array, Nil, fn(_, item) {
          case decode.run(item, decode.string) {
            Ok(_) -> Ok(Nil)
            Error(_) ->
              Error(errors.invalid_schema(
                def_name <> ": knownValues must be strings",
              ))
          }
        })
      }
      None -> Ok(Nil)
    }
  })
  |> result.try(fn(_) {
    // Validate const/default exclusivity
    let has_const = json_helpers.get_string(schema, "const") != option.None
    let has_default = json_helpers.get_string(schema, "default") != option.None

    constraints.validate_const_default_exclusivity(
      def_name,
      has_const,
      has_default,
      "string",
    )
  })
}

/// Validates string data against schema
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Check data is a string
  case json_helpers.is_string(data) {
    False ->
      Error(errors.data_validation(
        def_name <> ": expected string, got other type",
      ))
    True -> {
      // Extract the string value
      let json_str = json.to_string(data)
      // Remove quotes from JSON string representation
      let value = case
        string.starts_with(json_str, "\"") && string.ends_with(json_str, "\"")
      {
        True -> string.slice(json_str, 1, string.length(json_str) - 2)
        False -> json_str
      }

      // Validate length constraints
      let min_length = json_helpers.get_int(schema, "minLength")
      let max_length = json_helpers.get_int(schema, "maxLength")
      use _ <- result.try(validate_string_length(
        value,
        min_length,
        max_length,
        def_name,
      ))

      // Validate grapheme constraints
      let min_graphemes = json_helpers.get_int(schema, "minGraphemes")
      let max_graphemes = json_helpers.get_int(schema, "maxGraphemes")
      use _ <- result.try(validate_grapheme_length(
        value,
        min_graphemes,
        max_graphemes,
        def_name,
      ))

      // Validate format if specified
      case json_helpers.get_string(schema, "format") {
        Some(format_str) ->
          case types.string_to_format(format_str) {
            Ok(format) -> validate_string_format(value, format, def_name)
            Error(_) -> Ok(Nil)
          }
        None -> Ok(Nil)
      }
      |> result.try(fn(_) {
        // Validate enum if specified
        case json_helpers.get_array(schema, "enum") {
          Some(enum_array) -> {
            // Convert dynamics to strings
            let enum_strings =
              list.filter_map(enum_array, fn(item) {
                decode.run(item, decode.string)
              })

            validate_string_enum(value, enum_strings, def_name)
          }
          None -> Ok(Nil)
        }
      })
    }
  }
}

/// Helper to validate string length (UTF-8 bytes)
fn validate_string_length(
  value: String,
  min_length: Option(Int),
  max_length: Option(Int),
  def_name: String,
) -> Result(Nil, ValidationError) {
  let byte_length = string.byte_size(value)
  constraints.validate_length_constraints(
    def_name,
    byte_length,
    min_length,
    max_length,
    "string",
  )
}

/// Helper to validate grapheme length (visual characters)
fn validate_grapheme_length(
  value: String,
  min_graphemes: Option(Int),
  max_graphemes: Option(Int),
  def_name: String,
) -> Result(Nil, ValidationError) {
  // Count grapheme clusters (visual characters) using Gleam's stdlib
  // This correctly handles Unicode combining characters, emoji, etc.
  let grapheme_count = value |> string.to_graphemes() |> list.length()
  constraints.validate_length_constraints(
    def_name,
    grapheme_count,
    min_graphemes,
    max_graphemes,
    "string (graphemes)",
  )
}

/// Helper to validate string format
fn validate_string_format(
  value: String,
  format: types.StringFormat,
  def_name: String,
) -> Result(Nil, ValidationError) {
  case formats.validate_format(value, format) {
    True -> Ok(Nil)
    False -> {
      let format_name = types.format_to_string(format)
      Error(errors.data_validation(
        def_name <> ": string does not match format '" <> format_name <> "'",
      ))
    }
  }
}

/// Helper to validate string enum
fn validate_string_enum(
  value: String,
  enum_values: List(String),
  def_name: String,
) -> Result(Nil, ValidationError) {
  constraints.validate_enum_constraint(
    def_name,
    value,
    enum_values,
    "string",
    fn(s) { s },
    fn(a, b) { a == b },
  )
}
