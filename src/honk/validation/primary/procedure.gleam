// Procedure type validator
// Procedures are XRPC Procedure (HTTP POST) endpoints for modifying data

import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleam/result
import honk/errors
import honk/internal/constraints
import honk/internal/json_helpers
import honk/validation/context.{type ValidationContext}
import honk/validation/field as validation_field
import honk/validation/field/reference as validation_field_reference
import honk/validation/field/union as validation_field_union
import honk/validation/primary/params

const allowed_fields = [
  "type", "parameters", "input", "output", "errors", "description",
]

/// Validates procedure schema definition
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
    "procedure",
  ))

  // Validate parameters field if present
  use _ <- result.try(case json_helpers.get_field(schema, "parameters") {
    Some(parameters) -> validate_parameters_schema(parameters, ctx)
    None -> Ok(Nil)
  })

  // Validate input field if present
  use _ <- result.try(case json_helpers.get_field(schema, "input") {
    Some(input) -> validate_io_schema(def_name, input, "input")
    None -> Ok(Nil)
  })

  // Validate output field if present
  use _ <- result.try(case json_helpers.get_field(schema, "output") {
    Some(output) -> validate_io_schema(def_name, output, "output")
    None -> Ok(Nil)
  })

  // Validate errors field if present
  case json_helpers.get_array(schema, "errors") {
    Some(_) -> Ok(Nil)
    None -> Ok(Nil)
  }
}

/// Validates procedure input data against schema
/// Data should be the procedure input body as JSON
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  // If schema has input, validate data against it
  case json_helpers.get_field(schema, "input") {
    Some(input) -> {
      let input_ctx = context.with_path(ctx, "input")
      validate_body_data(data, input, input_ctx)
    }
    None -> Ok(Nil)
  }
}

/// Validates procedure output data against schema
pub fn validate_output_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  // If schema has output, validate data against it
  case json_helpers.get_field(schema, "output") {
    Some(output) -> {
      let output_ctx = context.with_path(ctx, "output")
      validate_body_data(data, output, output_ctx)
    }
    None -> Ok(Nil)
  }
}

/// Validates data against a SchemaBody (input or output)
fn validate_body_data(
  data: Json,
  body: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  // Get the schema field from the body
  case json_helpers.get_field(body, "schema") {
    Some(schema) -> {
      let schema_ctx = context.with_path(ctx, "schema")
      // Dispatch to appropriate validator based on schema type
      validate_body_schema_data(data, schema, schema_ctx)
    }
    None -> Ok(Nil)
  }
}

/// Validates data against a body schema (object, ref, or union)
fn validate_body_schema_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  case json_helpers.get_string(schema, "type") {
    Some("object") -> validation_field.validate_object_data(data, schema, ctx)
    Some("ref") -> {
      // For references, we need to resolve and validate
      // For now, just validate it's structured correctly
      validation_field_reference.validate_data(data, schema, ctx)
    }
    Some("union") -> validation_field_union.validate_data(data, schema, ctx)
    Some(other_type) ->
      Error(errors.data_validation(
        context.path(ctx)
        <> ": unsupported body schema type '"
        <> other_type
        <> "'",
      ))
    None ->
      Error(errors.data_validation(
        context.path(ctx) <> ": body schema missing type field",
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

/// Validates input/output schema definition
fn validate_io_schema(
  def_name: String,
  io: Json,
  field_name: String,
) -> Result(Nil, errors.ValidationError) {
  // Input/output must have encoding field
  case json_helpers.get_string(io, "encoding") {
    Some(_) -> Ok(Nil)
    None ->
      Error(errors.invalid_schema(
        def_name <> ": procedure " <> field_name <> " missing encoding field",
      ))
  }
}
