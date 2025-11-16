// Reference type validator

import errors.{type ValidationError}
import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import json_helpers
import validation/constraints
import validation/context.{type ValidationContext}
import validation/resolution

const allowed_fields = ["type", "ref", "description"]

/// Validates reference schema definition
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
    "ref",
  ))

  // Validate ref field (required)
  let ref_value = case json_helpers.get_string(schema, "ref") {
    Some(ref_str) -> Ok(ref_str)
    None ->
      Error(errors.invalid_schema(
        def_name <> ": ref missing required 'ref' field",
      ))
  }

  use ref_str <- result.try(ref_value)

  // Validate reference syntax
  validate_ref_syntax(ref_str, def_name)
}

/// Validates data against the referenced schema
/// Uses the validator from the context for recursive validation
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, ValidationError) {
  let def_name = context.path(ctx)

  // Get the reference string
  use ref_str <- result.try(case json_helpers.get_string(schema, "ref") {
    Some(ref_str) -> Ok(ref_str)
    None ->
      Error(errors.data_validation(
        def_name <> ": ref schema missing 'ref' field",
      ))
  })

  // Check for circular references
  case context.has_reference(ctx, ref_str) {
    True ->
      Error(errors.data_validation(
        def_name <> ": circular reference detected: " <> ref_str,
      ))
    False -> {
      // Add to reference stack
      let ref_ctx = context.with_reference(ctx, ref_str)

      // Get current lexicon ID
      use lex_id <- result.try(case context.current_lexicon_id(ref_ctx) {
        Some(id) -> Ok(id)
        None ->
          Error(errors.data_validation(
            def_name <> ": no current lexicon set for resolving reference",
          ))
      })

      // Resolve the reference to get the target schema
      use resolved_opt <- result.try(resolution.resolve_reference(
        ref_str,
        ref_ctx,
        lex_id,
      ))

      use resolved_schema <- result.try(case resolved_opt {
        Some(schema) -> Ok(schema)
        None ->
          Error(errors.data_validation(
            def_name <> ": reference not found: " <> ref_str,
          ))
      })

      // Recursively validate data against the resolved schema
      // Use the validator from the context
      let validator = ref_ctx.validator
      validator(data, resolved_schema, ref_ctx)
    }
  }
}

/// Validates reference syntax
fn validate_ref_syntax(
  ref_str: String,
  def_name: String,
) -> Result(Nil, ValidationError) {
  case string.is_empty(ref_str) {
    True ->
      Error(errors.invalid_schema(def_name <> ": reference cannot be empty"))
    False -> {
      case string.starts_with(ref_str, "#") {
        True -> {
          // Local reference
          let def_part = string.drop_start(ref_str, 1)
          case string.is_empty(def_part) {
            True ->
              Error(errors.invalid_schema(
                def_name
                <> ": local reference must have a definition name after #",
              ))
            False -> Ok(Nil)
          }
        }
        False -> {
          // Global reference (with or without fragment)
          case string.contains(ref_str, "#") {
            True -> {
              // Global reference with fragment
              validate_global_ref_with_fragment(ref_str, def_name)
            }
            False -> {
              // Global main reference
              // Would validate NSID format here
              Ok(Nil)
            }
          }
        }
      }
    }
  }
}

/// Validates global reference with fragment (e.g., "com.example.lexicon#def")
fn validate_global_ref_with_fragment(
  ref_str: String,
  def_name: String,
) -> Result(Nil, ValidationError) {
  // Split on # and validate both parts
  case string.split(ref_str, "#") {
    [nsid, definition] -> {
      case string.is_empty(nsid) {
        True ->
          Error(errors.invalid_schema(
            def_name <> ": NSID part of reference cannot be empty",
          ))
        False ->
          case string.is_empty(definition) {
            True ->
              Error(errors.invalid_schema(
                def_name
                <> ": definition name part of reference cannot be empty",
              ))
            False -> Ok(Nil)
          }
      }
    }
    _ ->
      Error(errors.invalid_schema(
        def_name <> ": global reference can only contain one # character",
      ))
  }
}
