// Query type validator
// Queries are XRPC Query (HTTP GET) endpoints for retrieving data

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
import honk/validation/primary/params
import honk/validation/primitive/boolean as validation_primitive_boolean
import honk/validation/primitive/integer as validation_primitive_integer
import honk/validation/primitive/string as validation_primitive_string

const allowed_fields = ["type", "parameters", "output", "errors", "description"]

/// Validates query schema definition
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
    "query",
  ))

  // Validate parameters field if present
  use _ <- result.try(case json_helpers.get_field(schema, "parameters") {
    Some(parameters) -> validate_parameters_schema(parameters, ctx)
    None -> Ok(Nil)
  })

  // Validate output field if present
  use _ <- result.try(case json_helpers.get_field(schema, "output") {
    Some(output) -> validate_output_schema(def_name, output)
    None -> Ok(Nil)
  })

  // Validate errors field if present
  case json_helpers.get_array(schema, "errors") {
    Some(_) -> Ok(Nil)
    None -> Ok(Nil)
  }
}

/// Validates query data against schema
/// Data should be the query parameters as a JSON object
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Query data must be an object (the parameters)
  use _ <- result.try(case json_helpers.is_object(data) {
    True -> Ok(Nil)
    False ->
      Error(errors.data_validation(
        def_name <> ": query parameters must be an object",
      ))
  })

  // If schema has parameters, validate data against them
  case json_helpers.get_field(schema, "parameters") {
    Some(parameters) -> {
      let params_ctx = context.with_path(ctx, "parameters")
      validate_parameters_data(data, parameters, params_ctx)
    }
    None -> Ok(Nil)
  }
}

/// Validates parameter data against params schema
fn validate_parameters_data(
  data: Json,
  params_schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  let def_name = context.path(ctx)

  // Get data as dict
  use data_dict <- result.try(json_helpers.json_to_dict(data))

  // Get properties and required from params schema
  let properties_dict = case
    json_helpers.get_field(params_schema, "properties")
  {
    Some(props) -> json_helpers.json_to_dict(props)
    None -> Ok(json_helpers.empty_dict())
  }

  let required_array = json_helpers.get_array(params_schema, "required")

  use props_dict <- result.try(properties_dict)

  // Check all required parameters are present
  use _ <- result.try(case required_array {
    Some(required) -> {
      list.try_fold(required, Nil, fn(_, item) {
        case decode.run(item, decode.string) {
          Ok(param_name) -> {
            case json_helpers.dict_has_key(data_dict, param_name) {
              True -> Ok(Nil)
              False ->
                Error(errors.data_validation(
                  def_name
                  <> ": missing required parameter '"
                  <> param_name
                  <> "'",
                ))
            }
          }
          Error(_) -> Ok(Nil)
        }
      })
    }
    None -> Ok(Nil)
  })

  // Validate each parameter in data
  json_helpers.dict_fold(data_dict, Ok(Nil), fn(acc, param_name, param_value) {
    case acc {
      Error(e) -> Error(e)
      Ok(_) -> {
        // Get the schema for this parameter
        case json_helpers.dict_get(props_dict, param_name) {
          Some(param_schema_dyn) -> {
            // Convert dynamic to JSON
            case json_helpers.dynamic_to_json(param_schema_dyn) {
              Ok(param_schema) -> {
                // Convert param value to JSON
                case json_helpers.dynamic_to_json(param_value) {
                  Ok(param_json) -> {
                    // Validate the parameter value against its schema
                    let param_ctx = context.with_path(ctx, param_name)
                    validate_parameter_value(
                      param_json,
                      param_schema,
                      param_ctx,
                    )
                  }
                  Error(e) -> Error(e)
                }
              }
              Error(e) -> Error(e)
            }
          }
          None -> {
            // Parameter not in schema - could warn or allow
            // For now, allow unknown parameters
            Ok(Nil)
          }
        }
      }
    }
  })
}

/// Validates a single parameter value against its schema
fn validate_parameter_value(
  value: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  // Dispatch based on schema type
  case json_helpers.get_string(schema, "type") {
    Some("boolean") ->
      validation_primitive_boolean.validate_data(value, schema, ctx)
    Some("integer") ->
      validation_primitive_integer.validate_data(value, schema, ctx)
    Some("string") ->
      validation_primitive_string.validate_data(value, schema, ctx)
    Some("unknown") -> validation_meta_unknown.validate_data(value, schema, ctx)
    Some("array") -> validation_field.validate_array_data(value, schema, ctx)
    Some(other_type) ->
      Error(errors.data_validation(
        context.path(ctx)
        <> ": unsupported parameter type '"
        <> other_type
        <> "'",
      ))
    None ->
      Error(errors.data_validation(
        context.path(ctx) <> ": parameter schema missing type field",
      ))
  }
}

/// Validates parameters schema definition
fn validate_parameters_schema(
  parameters: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  // Validate the full params schema
  let params_ctx = context.with_path(ctx, "parameters")
  params.validate_schema(parameters, params_ctx)
}

/// Validates output schema definition
fn validate_output_schema(
  def_name: String,
  output: Json,
) -> Result(Nil, errors.ValidationError) {
  // Output must have encoding field
  case json_helpers.get_string(output, "encoding") {
    Some(_) -> Ok(Nil)
    None ->
      Error(errors.invalid_schema(
        def_name <> ": query output missing encoding field",
      ))
  }
}
