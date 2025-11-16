// Params type validator
// Mirrors the Go implementation's validation/primary/params
// Params define query/procedure/subscription parameters (XRPC endpoint arguments)

import honk/errors as errors
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}
import honk/validation/field as validation_field
import honk/validation/meta/unknown as validation_meta_unknown
import honk/validation/primitive/boolean as validation_primitive_boolean
import honk/validation/primitive/integer as validation_primitive_integer
import honk/validation/primitive/string as validation_primitive_string

const allowed_fields = ["type", "description", "properties", "required"]

/// Validates params schema definition
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
    "params",
  ))

  // Validate type field
  use _ <- result.try(case json_helpers.get_string(schema, "type") {
    Some("params") -> Ok(Nil)
    Some(other_type) ->
      Error(errors.invalid_schema(
        def_name <> ": expected type 'params', got '" <> other_type <> "'",
      ))
    None ->
      Error(errors.invalid_schema(def_name <> ": params missing type field"))
  })

  // Get properties and required fields
  let properties_dict = case json_helpers.get_field(schema, "properties") {
    Some(props) -> json_helpers.json_to_dict(props)
    None -> Ok(json_helpers.empty_dict())
  }

  let required_array = case json_helpers.get_array(schema, "required") {
    Some(arr) -> Some(arr)
    None -> None
  }

  // Validate required fields exist in properties
  use props_dict <- result.try(properties_dict)
  use _ <- result.try(validate_required_fields(
    def_name,
    required_array,
    props_dict,
  ))

  // Validate each property
  validate_properties(def_name, props_dict, ctx)
}

/// Validates that all required fields exist in properties
fn validate_required_fields(
  def_name: String,
  required_array: option.Option(List(decode.Dynamic)),
  properties_dict: json_helpers.JsonDict,
) -> Result(Nil, errors.ValidationError) {
  case required_array {
    None -> Ok(Nil)
    Some(required) -> {
      list.try_fold(required, Nil, fn(_, item) {
        case decode.run(item, decode.string) {
          Ok(field_name) -> {
            case json_helpers.dict_has_key(properties_dict, field_name) {
              True -> Ok(Nil)
              False ->
                Error(errors.invalid_schema(
                  def_name
                  <> ": required field '"
                  <> field_name
                  <> "' not found in properties",
                ))
            }
          }
          Error(_) ->
            Error(errors.invalid_schema(
              def_name <> ": required field must be a string",
            ))
        }
      })
    }
  }
}

/// Validates all properties in the params
fn validate_properties(
  def_name: String,
  properties_dict: json_helpers.JsonDict,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  json_helpers.dict_fold(properties_dict, Ok(Nil), fn(acc, key, value) {
    case acc {
      Error(e) -> Error(e)
      Ok(_) -> {
        // Check property name is not empty
        use _ <- result.try(case key {
          "" ->
            Error(errors.invalid_schema(
              def_name <> ": empty property name not allowed",
            ))
          _ -> Ok(Nil)
        })

        // Convert dynamic value to JSON
        use prop_json <- result.try(case json_helpers.dynamic_to_json(value) {
          Ok(j) -> Ok(j)
          Error(_) ->
            Error(errors.invalid_schema(
              def_name <> ": invalid property value for '" <> key <> "'",
            ))
        })

        // Validate property type restrictions
        validate_property_type(def_name, key, prop_json, ctx)
      }
    }
  })
}

/// Validates that a property has an allowed type
/// Allowed types: boolean, integer, string, unknown, or arrays of these
fn validate_property_type(
  def_name: String,
  property_name: String,
  property_schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let prop_path = def_name <> ".properties." <> property_name

  case json_helpers.get_string(property_schema, "type") {
    Some("boolean") | Some("integer") | Some("string") | Some("unknown") -> {
      // These are allowed types - recursively validate the schema
      let prop_ctx = context.with_path(ctx, "properties." <> property_name)
      validate_property_schema(property_schema, prop_ctx)
    }
    Some("array") -> {
      // Arrays are allowed, but items must be one of the allowed types
      case json_helpers.get_field(property_schema, "items") {
        Some(items) -> {
          case json_helpers.get_string(items, "type") {
            Some("boolean") | Some("integer") | Some("string") | Some("unknown") -> {
              // Valid array item type - recursively validate
              let prop_ctx =
                context.with_path(ctx, "properties." <> property_name)
              validate_property_schema(property_schema, prop_ctx)
            }
            Some(other_type) ->
              Error(errors.invalid_schema(
                prop_path
                <> ": params array items must be boolean, integer, string, or unknown, got '"
                <> other_type
                <> "'",
              ))
            None ->
              Error(errors.invalid_schema(
                prop_path <> ": array items missing type field",
              ))
          }
        }
        None ->
          Error(errors.invalid_schema(
            prop_path <> ": array property missing items field",
          ))
      }
    }
    Some(other_type) ->
      Error(errors.invalid_schema(
        prop_path
        <> ": params properties must be boolean, integer, string, unknown, or arrays of these, got '"
        <> other_type
        <> "'",
      ))
    None ->
      Error(errors.invalid_schema(prop_path <> ": property missing type field"))
  }
}

/// Validates a property schema by dispatching to the appropriate validator
fn validate_property_schema(
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  case json_helpers.get_string(schema, "type") {
    Some("boolean") -> validation_primitive_boolean.validate_schema(schema, ctx)
    Some("integer") -> validation_primitive_integer.validate_schema(schema, ctx)
    Some("string") -> validation_primitive_string.validate_schema(schema, ctx)
    Some("unknown") -> validation_meta_unknown.validate_schema(schema, ctx)
    Some("array") -> validation_field.validate_array_schema(schema, ctx)
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

/// Validates params data against schema
pub fn validate_data(
  _data: Json,
  _schema: Json,
  _ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  // Params data validation would check that all required parameters are present
  // and that each parameter value matches its schema
  // For now, simplified implementation
  Ok(Nil)
}
