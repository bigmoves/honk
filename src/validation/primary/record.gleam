// Record type validator

import errors.{type ValidationError}
import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import json_helpers
import validation/constraints
import validation/context.{type ValidationContext}
import validation/field

const allowed_fields = ["type", "key", "record", "description"]

const allowed_record_fields = [
  "type", "properties", "required", "nullable", "description",
]

/// Validates record schema definition
pub fn validate_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Validate allowed fields at record level
  let keys = json_helpers.get_keys(schema)
  use _ <- result.try(constraints.validate_allowed_fields(
    def_name,
    keys,
    allowed_fields,
    "record",
  ))

  // Validate required 'key' field
  let key_value = case json_helpers.get_string(schema, "key") {
    Some(key) -> Ok(key)
    None ->
      Error(errors.invalid_schema(
        def_name <> ": record missing required 'key' field",
      ))
  }

  use key <- result.try(key_value)
  use _ <- result.try(validate_key(def_name, key))

  // Validate required 'record' field
  let record_def = case json_helpers.get_field(schema, "record") {
    Some(record) -> Ok(record)
    None ->
      Error(errors.invalid_schema(
        def_name <> ": record missing required 'record' field",
      ))
  }

  use record <- result.try(record_def)

  // Validate record object structure
  use _ <- result.try(validate_record_object(def_name, record))

  // Recursively validate properties - delegate to object validator
  // The record field is an object, so we can use field.validate_object_schema
  let record_ctx = context.with_path(ctx, ".record")
  field.validate_object_schema(record, record_ctx)
}

/// Validates record data against schema
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Data must be an object
  case json_helpers.is_object(data) {
    False -> {
      Error(errors.data_validation(def_name <> ": expected object for record"))
    }
    True -> {
      // Get the record definition
      case json_helpers.get_field(schema, "record") {
        Some(record_def) -> {
          // Delegate to object validator for full validation
          // The record's data validation is the same as object validation
          field.validate_object_data(data, record_def, ctx)
        }
        None ->
          Error(errors.data_validation(
            def_name <> ": record schema missing 'record' field",
          ))
      }
    }
  }
}

/// Validates the `key` field of a record definition
///
/// Valid key types:
/// - `tid`: Record key is a Timestamp Identifier (auto-generated)
/// - `any`: Record key can be any valid record key format
/// - `nsid`: Record key must be a valid NSID
/// - `literal:*`: Record key must match the literal value after the colon
fn validate_key(def_name: String, key: String) -> Result(Nil, ValidationError) {
  case key {
    "tid" -> Ok(Nil)
    "any" -> Ok(Nil)
    "nsid" -> Ok(Nil)
    _ ->
      case string.starts_with(key, "literal:") {
        True -> Ok(Nil)
        False ->
          Error(errors.invalid_schema(
            def_name
            <> ": record has invalid key type '"
            <> key
            <> "'. Must be 'tid', 'any', 'nsid', or 'literal:*'",
          ))
      }
  }
}

/// Validates the structure of a record object definition
fn validate_record_object(
  def_name: String,
  record_def: Json,
) -> Result(Nil, ValidationError) {
  // Must be type "object"
  case json_helpers.get_string(record_def, "type") {
    Some("object") -> {
      // Validate allowed fields in record object
      let keys = json_helpers.get_keys(record_def)
      use _ <- result.try(constraints.validate_allowed_fields(
        def_name,
        keys,
        allowed_record_fields,
        "record object",
      ))

      // Validate properties structure
      use _ <- result.try(
        case json_helpers.get_field(record_def, "properties") {
          Some(properties) ->
            case json_helpers.is_object(properties) {
              True -> Ok(Nil)
              False ->
                Error(errors.invalid_schema(
                  def_name <> ": record properties must be an object",
                ))
            }
          None -> Ok(Nil)
        },
      )

      // Validate nullable is an array if present
      case json_helpers.get_array(record_def, "nullable") {
        Some(_) -> Ok(Nil)
        None -> {
          // Check if nullable exists but is not an array
          case json_helpers.get_field(record_def, "nullable") {
            Some(_) ->
              Error(errors.invalid_schema(
                def_name <> ": record nullable field must be an array",
              ))
            None -> Ok(Nil)
          }
        }
      }
    }
    Some(other_type) ->
      Error(errors.invalid_schema(
        def_name
        <> ": record field must be type 'object', got '"
        <> other_type
        <> "'",
      ))
    None ->
      Error(errors.invalid_schema(def_name <> ": record field missing type"))
  }
}
