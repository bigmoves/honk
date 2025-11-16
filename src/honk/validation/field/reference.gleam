// Reference type validator

import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import honk/errors
import honk/internal/constraints
import honk/internal/json_helpers
import honk/internal/resolution
import honk/validation/context.{type ValidationContext}

const allowed_fields = ["type", "ref", "description"]

/// Validates reference schema definition
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
  use _ <- result.try(validate_ref_syntax(ref_str, def_name))

  // Validate that the reference can be resolved (only for global refs with full context)
  case string.starts_with(ref_str, "#") {
    True -> Ok(Nil)
    // Local ref - will be validated in same lexicon
    False -> {
      // Global ref - check it exists in catalog if we have a current lexicon
      case context.current_lexicon_id(ctx) {
        Some(lex_id) -> {
          // We have a full validation context, so validate reference resolution
          use resolved <- result.try(resolution.resolve_reference(
            ref_str,
            ctx,
            lex_id,
          ))

          case resolved {
            Some(_) -> Ok(Nil)
            None ->
              Error(errors.invalid_schema(
                def_name <> ": reference not found: " <> ref_str,
              ))
          }
        }
        None -> {
          // No current lexicon (e.g., unit test context)
          // Just validate syntax, can't check if reference exists
          Ok(Nil)
        }
      }
    }
  }
}

/// Validates data against the referenced schema
/// Uses the validator from the context for recursive validation
pub fn validate_data(
  data: Json,
  schema: Json,
  ctx: ValidationContext,
) -> Result(Nil, errors.ValidationError) {
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
) -> Result(Nil, errors.ValidationError) {
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
) -> Result(Nil, errors.ValidationError) {
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
