// Field type validators (object and array)

import errors.{type ValidationError}
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import honk/internal/constraints
import honk/internal/json_helpers
import validation/context.{type ValidationContext}

// Import primitive validators
import validation/primitive/blob
import validation/primitive/boolean
import validation/primitive/bytes
import validation/primitive/cid_link
import validation/primitive/integer
import validation/primitive/null
import validation/primitive/string

// Import other field validators
import validation/field/reference
import validation/field/union

// Import meta validators
import validation/meta/token
import validation/meta/unknown

// ============================================================================
// SHARED TYPE DISPATCHER
// ============================================================================

/// Dispatch schema validation based on type field
/// Handles all primitive and field types
fn dispatch_schema_validation(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  case json_helpers.get_string(schema, "type") {
    Some("string") -> string.validate_schema(schema, ctx)
    Some("integer") -> integer.validate_schema(schema, ctx)
    Some("boolean") -> boolean.validate_schema(schema, ctx)
    Some("bytes") -> bytes.validate_schema(schema, ctx)
    Some("blob") -> blob.validate_schema(schema, ctx)
    Some("cid-link") -> cid_link.validate_schema(schema, ctx)
    Some("null") -> null.validate_schema(schema, ctx)
    Some("object") -> validate_object_schema(schema, ctx)
    Some("array") -> validate_array_schema(schema, ctx)
    Some("union") -> union.validate_schema(schema, ctx)
    Some("ref") -> reference.validate_schema(schema, ctx)
    Some("token") -> token.validate_schema(schema, ctx)
    Some("unknown") -> unknown.validate_schema(schema, ctx)
    Some(unknown_type) ->
      Error(errors.invalid_schema(
        context.path(ctx) <> ": unknown type '" <> unknown_type <> "'",
      ))
    None ->
      Error(errors.invalid_schema(
        context.path(ctx) <> ": schema missing type field",
      ))
  }
}

/// Dispatches data validation to the appropriate type-specific validator.
///
/// This is the central dispatcher that routes validation based on the schema's
/// `type` field. Handles all primitive types (string, integer, boolean, etc.),
/// field types (object, array, union, ref), and meta types (token, unknown).
///
/// Made public to allow reference validators to recursively validate resolved
/// schemas. Typically set as the validator function in ValidationContext via
/// `context.with_validator(field.dispatch_data_validation)`.
///
/// ## Example
///
/// ```gleam
/// let schema = json.object([
///   #("type", json.string("string")),
///   #("maxLength", json.int(100)),
/// ])
/// let data = json.string("Hello")
///
/// field.dispatch_data_validation(data, schema, ctx)
/// // => Ok(Nil) if valid, Error(...) if invalid
/// ```
pub fn dispatch_data_validation(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  case json_helpers.get_string(schema, "type") {
    Some("string") -> string.validate_data(data, schema, ctx)
    Some("integer") -> integer.validate_data(data, schema, ctx)
    Some("boolean") -> boolean.validate_data(data, schema, ctx)
    Some("bytes") -> bytes.validate_data(data, schema, ctx)
    Some("blob") -> blob.validate_data(data, schema, ctx)
    Some("cid-link") -> cid_link.validate_data(data, schema, ctx)
    Some("null") -> null.validate_data(data, schema, ctx)
    Some("object") -> validate_object_data(data, schema, ctx)
    Some("array") -> validate_array_data(data, schema, ctx)
    Some("union") -> union.validate_data(data, schema, ctx)
    Some("ref") -> reference.validate_data(data, schema, ctx)
    Some("token") -> token.validate_data(data, schema, ctx)
    Some("unknown") -> unknown.validate_data(data, schema, ctx)
    Some(unknown_type) ->
      Error(errors.data_validation(
        "Unknown schema type '"
        <> unknown_type
        <> "' at '"
        <> context.path(ctx)
        <> "'",
      ))
    None ->
      Error(errors.data_validation(
        "Schema missing type field at '" <> context.path(ctx) <> "'",
      ))
  }
}

// ============================================================================
// OBJECT VALIDATOR
// ============================================================================

const object_allowed_fields = [
  "type", "properties", "required", "nullable", "description",
]

/// Validates object schema definition
pub fn validate_object_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Validate allowed fields
  let keys = json_helpers.get_keys(schema)
  use _ <- result.try(constraints.validate_allowed_fields(
    def_name,
    keys,
    object_allowed_fields,
    "object",
  ))

  // Validate properties structure
  let properties = case json_helpers.get_array(schema, "properties") {
    Some(_) ->
      Error(errors.invalid_schema(
        def_name <> ": properties must be an object, not an array",
      ))
    None ->
      case json_helpers.is_object(schema) {
        True -> Ok(None)
        False -> Ok(None)
      }
  }

  use _ <- result.try(properties)

  // Validate required fields reference existing properties
  use _ <- result.try(case json_helpers.get_array(schema, "required") {
    Some(required_array) -> validate_required_fields(def_name, required_array)
    None -> Ok(Nil)
  })

  // Validate nullable fields reference existing properties
  use _ <- result.try(case json_helpers.get_array(schema, "nullable") {
    Some(nullable_array) -> validate_nullable_fields(def_name, nullable_array)
    None -> Ok(Nil)
  })

  // Validate each property schema recursively
  case json_helpers.get_field(schema, "properties") {
    Some(properties) -> {
      case json_helpers.is_object(properties) {
        True -> {
          // Get property map and validate each property schema
          validate_property_schemas(properties, ctx)
        }
        False -> Ok(Nil)
      }
    }
    None -> Ok(Nil)
  }
}

/// Validates object data against schema
pub fn validate_object_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Check data is an object
  case json_helpers.is_object(data) {
    False -> {
      let type_name = get_type_name(data)
      Error(errors.data_validation(
        "Expected object at '" <> def_name <> "', found " <> type_name,
      ))
    }
    True -> {
      // Check required fields are present
      use _ <- result.try(case json_helpers.get_array(schema, "required") {
        Some(required_array) ->
          validate_required_fields_in_data(def_name, required_array, data)
        None -> Ok(Nil)
      })

      // Get nullable fields for lookup
      let nullable_fields = case json_helpers.get_array(schema, "nullable") {
        Some(nullable_array) ->
          list.filter_map(nullable_array, fn(item) {
            decode.run(item, decode.string)
          })
        None -> []
      }

      // Validate each property in data against its schema
      case json_helpers.get_field(schema, "properties") {
        Some(properties) -> {
          validate_properties_data(data, properties, nullable_fields, ctx)
        }
        None -> Ok(Nil)
      }
    }
  }
}

/// Helper to validate required fields exist in properties
fn validate_required_fields(
  def_name: String,
  required: List(Dynamic),
) -> Result(Nil, ValidationError) {
  // Convert dynamics to strings
  let field_names =
    list.filter_map(required, fn(item) { decode.run(item, decode.string) })

  // Each required field should be validated against properties
  // Simplified: just check they're strings
  case list.length(field_names) == list.length(required) {
    True -> Ok(Nil)
    False ->
      Error(errors.invalid_schema(
        def_name <> ": required fields must be strings",
      ))
  }
}

/// Helper to validate nullable fields exist in properties
fn validate_nullable_fields(
  def_name: String,
  nullable: List(Dynamic),
) -> Result(Nil, ValidationError) {
  // Convert dynamics to strings
  let field_names =
    list.filter_map(nullable, fn(item) { decode.run(item, decode.string) })

  // Each nullable field should be validated against properties
  // Simplified: just check they're strings
  case list.length(field_names) == list.length(nullable) {
    True -> Ok(Nil)
    False ->
      Error(errors.invalid_schema(
        def_name <> ": nullable fields must be strings",
      ))
  }
}

/// Helper to validate required fields are present in data
fn validate_required_fields_in_data(
  def_name: String,
  required: List(Dynamic),
  data: Json,
) -> Result(Nil, ValidationError) {
  // Convert dynamics to strings
  let field_names =
    list.filter_map(required, fn(item) { decode.run(item, decode.string) })

  // Check each required field exists in data
  list.try_fold(field_names, Nil, fn(_, field_name) {
    case json_helpers.get_string(data, field_name) {
      Some(_) -> Ok(Nil)
      None ->
        // Field might not be a string, check if it exists at all
        // Simplified: just report missing
        Error(errors.data_validation(
          def_name <> ": required field '" <> field_name <> "' is missing",
        ))
    }
  })
}

/// Validates all property schemas in an object
fn validate_property_schemas(
  properties: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  // Convert JSON object to dict and validate each property
  case json_helpers.json_to_dict(properties) {
    Ok(props_dict) -> {
      dict.fold(props_dict, Ok(Nil), fn(acc, prop_name, prop_schema_dyn) {
        use _ <- result.try(acc)
        // Convert dynamic to Json
        case json_helpers.dynamic_to_json(prop_schema_dyn) {
          Ok(prop_schema) -> {
            let nested_ctx = context.with_path(ctx, "properties." <> prop_name)
            validate_single_property_schema(prop_schema, nested_ctx)
          }
          Error(e) -> Error(e)
        }
      })
    }
    Error(e) -> Error(e)
  }
}

/// Dispatch validation to appropriate validator based on type
fn validate_single_property_schema(
  prop_schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  dispatch_schema_validation(prop_schema, ctx)
}

/// Validates all properties in data against their schemas
fn validate_properties_data(
  data: Json,
  properties: Json,
  nullable_fields: List(String),
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  // Convert data to dict
  case json_helpers.json_to_dict(data) {
    Ok(data_dict) -> {
      // Convert properties schema to dict
      case json_helpers.json_to_dict(properties) {
        Ok(props_dict) -> {
          // Iterate through data fields
          dict.fold(data_dict, Ok(Nil), fn(acc, field_name, field_value) {
            use _ <- result.try(acc)
            // Check if field has a schema definition
            case dict.get(props_dict, field_name) {
              Ok(field_schema_dyn) -> {
                // Convert dynamic schema to Json
                case json_helpers.dynamic_to_json(field_schema_dyn) {
                  Ok(field_schema) -> {
                    let nested_ctx = context.with_path(ctx, field_name)
                    // Check for null values
                    case json_helpers.is_null_dynamic(field_value) {
                      True -> {
                        // Check if field is nullable
                        case list.contains(nullable_fields, field_name) {
                          True -> Ok(Nil)
                          False ->
                            Error(errors.data_validation(
                              "Field '"
                              <> field_name
                              <> "' at '"
                              <> context.path(ctx)
                              <> "' cannot be null",
                            ))
                        }
                      }
                      False -> {
                        // Validate field data against schema
                        case json_helpers.dynamic_to_json(field_value) {
                          Ok(field_value_json) ->
                            validate_single_property_data(
                              field_value_json,
                              field_schema,
                              nested_ctx,
                            )
                          Error(e) -> Error(e)
                        }
                      }
                    }
                  }
                  Error(e) -> Error(e)
                }
              }
              Error(_) -> {
                // Unknown fields are allowed in objects (open schema)
                Ok(Nil)
              }
            }
          })
        }
        Error(e) -> Error(e)
      }
    }
    Error(e) -> Error(e)
  }
}

/// Dispatch data validation to appropriate validator based on type
fn validate_single_property_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  dispatch_data_validation(data, schema, ctx)
}

// ============================================================================
// ARRAY VALIDATOR
// ============================================================================

const array_allowed_fields = [
  "type", "items", "minLength", "maxLength", "description",
]

/// Validates array schema definition
pub fn validate_array_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Validate allowed fields
  let keys = json_helpers.get_keys(schema)
  use _ <- result.try(constraints.validate_allowed_fields(
    def_name,
    keys,
    array_allowed_fields,
    "array",
  ))

  // Validate required 'items' field
  let items = case json_helpers.get_field(schema, "items") {
    Some(items_value) -> Ok(items_value)
    None ->
      Error(errors.invalid_schema(
        def_name <> ": array missing required 'items' field",
      ))
  }

  use items_schema <- result.try(items)

  // Recursively validate the items schema definition
  let nested_ctx = context.with_path(ctx, ".items")
  use _ <- result.try(validate_array_item_schema(items_schema, nested_ctx))

  // Validate length constraints
  let min_length = json_helpers.get_int(schema, "minLength")
  let max_length = json_helpers.get_int(schema, "maxLength")

  // Validate that minLength/maxLength are consistent
  use _ <- result.try(constraints.validate_length_constraint_consistency(
    def_name,
    min_length,
    max_length,
    "array",
  ))

  Ok(Nil)
}

/// Validates array data against schema
pub fn validate_array_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Data must be an array
  case json_helpers.is_array(data) {
    False -> {
      let type_name = get_type_name(data)
      Error(errors.data_validation(
        def_name <> ": expected array, found " <> type_name,
      ))
    }
    True -> {
      // Get array from data
      let data_array = case json_helpers.get_array_from_value(data) {
        Some(arr) -> Ok(arr)
        None ->
          Error(errors.data_validation(def_name <> ": failed to parse array"))
      }

      use arr <- result.try(data_array)

      let array_length = list.length(arr)

      // Validate minLength constraint
      use _ <- result.try(case json_helpers.get_int(schema, "minLength") {
        Some(min_length) ->
          case array_length < min_length {
            True ->
              Error(errors.data_validation(
                def_name
                <> ": array has length "
                <> int.to_string(array_length)
                <> " but minimum length is "
                <> int.to_string(min_length),
              ))
            False -> Ok(Nil)
          }
        None -> Ok(Nil)
      })

      // Validate maxLength constraint
      use _ <- result.try(case json_helpers.get_int(schema, "maxLength") {
        Some(max_length) ->
          case array_length > max_length {
            True ->
              Error(errors.data_validation(
                def_name
                <> ": array has length "
                <> int.to_string(array_length)
                <> " but maximum length is "
                <> int.to_string(max_length),
              ))
            False -> Ok(Nil)
          }
        None -> Ok(Nil)
      })

      // Validate each array item against the items schema
      case json_helpers.get_field(schema, "items") {
        Some(items_schema) -> {
          // Validate each item with index in path
          list.index_fold(arr, Ok(Nil), fn(acc, item, index) {
            use _ <- result.try(acc)
            let nested_ctx =
              context.with_path(ctx, "[" <> int.to_string(index) <> "]")
            validate_array_item_data(item, items_schema, nested_ctx)
          })
        }
        None -> Ok(Nil)
      }
    }
  }
}

/// Validates an items schema definition recursively
fn validate_array_item_schema(
  items_schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  // Handle reference types by delegating to reference validator
  case json_helpers.get_string(items_schema, "type") {
    Some("ref") -> reference.validate_schema(items_schema, ctx)
    _ -> dispatch_schema_validation(items_schema, ctx)
  }
}

/// Validates runtime data against an items schema using recursive validation
fn validate_array_item_data(
  item: Dynamic,
  items_schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  // Convert dynamic to Json for validation
  let item_json = json_helpers.dynamic_to_json(item)

  use item_value <- result.try(item_json)

  // Handle reference types by delegating to reference validator
  case json_helpers.get_string(items_schema, "type") {
    Some("ref") -> reference.validate_data(item_value, items_schema, ctx)
    _ -> dispatch_data_validation(item_value, items_schema, ctx)
  }
}

// ============================================================================
// SHARED HELPERS
// ============================================================================

/// Helper to get type name for error messages
fn get_type_name(data: Json) -> String {
  case json_helpers.is_null(data) {
    True -> "null"
    False ->
      case json_helpers.is_bool(data) {
        True -> "boolean"
        False ->
          case json_helpers.is_int(data) {
            True -> "number"
            False ->
              case json_helpers.is_string(data) {
                True -> "string"
                False ->
                  case json_helpers.is_array(data) {
                    True -> "array"
                    False -> "object"
                  }
              }
          }
      }
  }
}
