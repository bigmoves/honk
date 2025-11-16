// Blob type validator
// Blobs are binary objects with MIME types and size constraints

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import honk/errors
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}

const allowed_fields = ["type", "accept", "maxSize", "description"]

/// Validates blob schema definition
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
    "blob",
  ))

  // Validate accept field if present
  use _ <- result.try(case json_helpers.get_array(schema, "accept") {
    Some(accept_array) -> validate_accept_field(def_name, accept_array)
    None -> Ok(Nil)
  })

  // Validate maxSize is positive integer if present
  case json_helpers.get_int(schema, "maxSize") {
    Some(max_size) ->
      case max_size > 0 {
        True -> Ok(Nil)
        False ->
          Error(errors.invalid_schema(
            def_name <> ": blob maxSize must be greater than 0",
          ))
      }
    None -> Ok(Nil)
  }
}

/// Validates blob data against schema
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Data must be an object
  case json_helpers.is_object(data) {
    False -> {
      Error(errors.data_validation(def_name <> ": expected blob object"))
    }
    True -> {
      // Validate required mimeType field
      use mime_type <- result.try(
        case json_helpers.get_string(data, "mimeType") {
          Some(mt) -> Ok(mt)
          None ->
            Error(errors.data_validation(
              def_name <> ": blob missing required 'mimeType' field",
            ))
        },
      )

      // Validate required size field
      use size <- result.try(case json_helpers.get_int(data, "size") {
        Some(s) -> Ok(s)
        None ->
          Error(errors.data_validation(
            def_name <> ": blob missing or invalid 'size' field",
          ))
      })

      // Validate against accept constraint if present
      use _ <- result.try(case json_helpers.get_array(schema, "accept") {
        Some(accept_array) -> {
          validate_mime_type_against_accept(def_name, mime_type, accept_array)
        }
        None -> Ok(Nil)
      })

      // Validate against maxSize constraint if present
      case json_helpers.get_int(schema, "maxSize") {
        Some(max_size) ->
          case size <= max_size {
            True -> Ok(Nil)
            False ->
              Error(errors.data_validation(
                def_name
                <> ": blob size "
                <> int.to_string(size)
                <> " exceeds maxSize "
                <> int.to_string(max_size),
              ))
          }
        None -> Ok(Nil)
      }
    }
  }
}

/// Validates accept field array
fn validate_accept_field(
  def_name: String,
  accept_array: List(Dynamic),
) -> Result(Nil, errors.ValidationError) {
  list.index_fold(accept_array, Ok(Nil), fn(acc, item, i) {
    use _ <- result.try(acc)
    case decode.run(item, decode.string) {
      Ok(mime_type) -> validate_mime_type_pattern(def_name, mime_type, i)
      Error(_) ->
        Error(errors.invalid_schema(
          def_name
          <> ": blob accept["
          <> int.to_string(i)
          <> "] must be a string",
        ))
    }
  })
}

/// Validates MIME type pattern syntax
fn validate_mime_type_pattern(
  def_name: String,
  mime_type: String,
  _index: Int,
) -> Result(Nil, errors.ValidationError) {
  case string.is_empty(mime_type) {
    True ->
      Error(errors.invalid_schema(
        def_name <> ": blob MIME type cannot be empty",
      ))
    False -> {
      // Allow */*
      case mime_type {
        "*/*" -> Ok(Nil)
        _ -> {
          // Must contain exactly one /
          case string.contains(mime_type, "/") {
            False ->
              Error(errors.invalid_schema(
                def_name
                <> ": blob MIME type '"
                <> mime_type
                <> "' must contain a '/' character",
              ))
            True -> {
              let parts = string.split(mime_type, "/")
              case parts {
                [type_part, subtype_part] -> {
                  // Validate * usage
                  use _ <- result.try(validate_wildcard(
                    def_name,
                    type_part,
                    "type",
                    mime_type,
                  ))
                  validate_wildcard(
                    def_name,
                    subtype_part,
                    "subtype",
                    mime_type,
                  )
                }
                _ ->
                  Error(errors.invalid_schema(
                    def_name
                    <> ": blob MIME type '"
                    <> mime_type
                    <> "' must have exactly one '/' character",
                  ))
              }
            }
          }
        }
      }
    }
  }
}

/// Validates wildcard usage in MIME type parts
fn validate_wildcard(
  def_name: String,
  part: String,
  part_name: String,
  full_mime_type: String,
) -> Result(Nil, errors.ValidationError) {
  case string.contains(part, "*") {
    True ->
      case part {
        "*" -> Ok(Nil)
        _ ->
          Error(errors.invalid_schema(
            def_name
            <> ": blob MIME type '"
            <> full_mime_type
            <> "' can only use '*' as a complete wildcard for "
            <> part_name,
          ))
      }
    False -> Ok(Nil)
  }
}

/// Validates MIME type against accept patterns
fn validate_mime_type_against_accept(
  def_name: String,
  mime_type: String,
  accept_array: List(Dynamic),
) -> Result(Nil, errors.ValidationError) {
  let accept_patterns =
    list.filter_map(accept_array, fn(item) { decode.run(item, decode.string) })

  // Check if mime_type matches any accept pattern
  case
    list.any(accept_patterns, fn(pattern) {
      mime_type_matches_pattern(mime_type, pattern)
    })
  {
    True -> Ok(Nil)
    False ->
      Error(errors.data_validation(
        def_name
        <> ": blob mimeType '"
        <> mime_type
        <> "' not accepted. Allowed: "
        <> string.join(accept_patterns, ", "),
      ))
  }
}

/// Checks if a MIME type matches a pattern
fn mime_type_matches_pattern(mime_type: String, pattern: String) -> Bool {
  case pattern {
    "*/*" -> True
    _ -> {
      let mime_parts = string.split(mime_type, "/")
      let pattern_parts = string.split(pattern, "/")
      case mime_parts, pattern_parts {
        [mime_type_part, mime_subtype], [pattern_type, pattern_subtype] -> {
          let type_matches = case pattern_type {
            "*" -> True
            _ -> mime_type_part == pattern_type
          }
          let subtype_matches = case pattern_subtype {
            "*" -> True
            _ -> mime_subtype == pattern_subtype
          }
          type_matches && subtype_matches
        }
        _, _ -> False
      }
    }
  }
}
