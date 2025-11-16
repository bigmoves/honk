// Main public API for the ATProtocol lexicon validator

import errors.{type ValidationError}
import gleam/dict.{type Dict}
import gleam/json.{type Json}
import gleam/option.{None, Some}
import gleam/result
import honk/internal/json_helpers
import types
import validation/context
import validation/formats

// Import validators
import validation/field as validation_field
import validation/field/reference as validation_field_reference
import validation/field/union as validation_field_union
import validation/meta/token as validation_meta_token
import validation/meta/unknown as validation_meta_unknown
import validation/primary/params as validation_primary_params
import validation/primary/procedure as validation_primary_procedure
import validation/primary/query as validation_primary_query
import validation/primary/record as validation_primary_record
import validation/primary/subscription as validation_primary_subscription
import validation/primitive/blob as validation_primitive_blob
import validation/primitive/boolean as validation_primitive_boolean
import validation/primitive/bytes as validation_primitive_bytes
import validation/primitive/cid_link as validation_primitive_cid_link
import validation/primitive/integer as validation_primitive_integer
import validation/primitive/null as validation_primitive_null
import validation/primitive/string as validation_primitive_string

// Re-export core types
pub type LexiconDoc =
  types.LexiconDoc

pub type StringFormat {
  DateTime
  Uri
  AtUri
  Did
  Handle
  AtIdentifier
  Nsid
  Cid
  Language
  Tid
  RecordKey
}

pub type ValidationContext =
  context.ValidationContext

/// Main validation function for lexicon documents
/// Returns Ok(Nil) if all lexicons are valid
/// Returns Error with a map of lexicon ID to list of error messages
pub fn validate(lexicons: List(Json)) -> Result(Nil, Dict(String, List(String))) {
  // Build validation context
  let builder_result =
    context.builder()
    |> context.with_lexicons(lexicons)

  case builder_result {
    Ok(builder) ->
      case context.build(builder) {
        Ok(ctx) -> {
          // Validate each lexicon's main definition
          let error_map =
            dict.fold(ctx.lexicons, dict.new(), fn(errors, lex_id, lexicon) {
              // Validate the main definition if it exists
              case json_helpers.get_field(lexicon.defs, "main") {
                Some(main_def) -> {
                  let lex_ctx = context.with_current_lexicon(ctx, lex_id)
                  case validate_definition(main_def, lex_ctx) {
                    Ok(_) -> errors
                    Error(e) ->
                      dict.insert(errors, lex_id, [errors.to_string(e)])
                  }
                }
                None -> errors
                // No main definition is OK
              }
            })

          case dict.is_empty(error_map) {
            True -> Ok(Nil)
            False -> Error(error_map)
          }
        }
        Error(e) -> Error(dict.from_list([#("builder", [errors.to_string(e)])]))
      }
    Error(e) -> Error(dict.from_list([#("builder", [errors.to_string(e)])]))
  }
}

/// Validates a single definition based on its type
fn validate_definition(
  def: Json,
  ctx: context.ValidationContext,
) -> Result(Nil, errors.ValidationError) {
  case json_helpers.get_string(def, "type") {
    Some("record") -> validation_primary_record.validate_schema(def, ctx)
    Some("query") -> validation_primary_query.validate_schema(def, ctx)
    Some("procedure") -> validation_primary_procedure.validate_schema(def, ctx)
    Some("subscription") ->
      validation_primary_subscription.validate_schema(def, ctx)
    Some("params") -> validation_primary_params.validate_schema(def, ctx)
    Some("object") -> validation_field.validate_object_schema(def, ctx)
    Some("array") -> validation_field.validate_array_schema(def, ctx)
    Some("union") -> validation_field_union.validate_schema(def, ctx)
    Some("string") -> validation_primitive_string.validate_schema(def, ctx)
    Some("integer") -> validation_primitive_integer.validate_schema(def, ctx)
    Some("boolean") -> validation_primitive_boolean.validate_schema(def, ctx)
    Some("bytes") -> validation_primitive_bytes.validate_schema(def, ctx)
    Some("blob") -> validation_primitive_blob.validate_schema(def, ctx)
    Some("cid-link") -> validation_primitive_cid_link.validate_schema(def, ctx)
    Some("null") -> validation_primitive_null.validate_schema(def, ctx)
    Some("ref") -> validation_field_reference.validate_schema(def, ctx)
    Some("token") -> validation_meta_token.validate_schema(def, ctx)
    Some("unknown") -> validation_meta_unknown.validate_schema(def, ctx)
    Some(unknown_type) ->
      Error(errors.invalid_schema("Unknown type: " <> unknown_type))
    None -> Error(errors.invalid_schema("Definition missing type field"))
  }
}

/// Validates a single data record against a collection schema
pub fn validate_record(
  lexicons: List(Json),
  collection: String,
  record: Json,
) -> Result(Nil, ValidationError) {
  // Build validation context
  let builder_result =
    context.builder()
    |> context.with_lexicons(lexicons)

  use builder <- result.try(builder_result)
  use ctx <- result.try(context.build(builder))

  // Get the lexicon for this collection
  case context.get_lexicon(ctx, collection) {
    Some(lexicon) -> {
      // Get the main definition (should be a record type)
      case json_helpers.get_field(lexicon.defs, "main") {
        Some(main_def) -> {
          let lex_ctx = context.with_current_lexicon(ctx, collection)
          // Validate the record data against the main definition
          validation_primary_record.validate_data(record, main_def, lex_ctx)
        }
        None ->
          Error(errors.invalid_schema(
            "Lexicon '" <> collection <> "' has no main definition",
          ))
      }
    }
    None -> Error(errors.lexicon_not_found(collection))
  }
}

/// Validates NSID format
pub fn is_valid_nsid(nsid: String) -> Bool {
  formats.is_valid_nsid(nsid)
}

/// Validates a string value against a specific format
pub fn validate_string_format(
  value: String,
  format: StringFormat,
) -> Result(Nil, String) {
  // Convert our StringFormat to types.StringFormat
  let types_format = case format {
    DateTime -> types.DateTime
    Uri -> types.Uri
    AtUri -> types.AtUri
    Did -> types.Did
    Handle -> types.Handle
    AtIdentifier -> types.AtIdentifier
    Nsid -> types.Nsid
    Cid -> types.Cid
    Language -> types.Language
    Tid -> types.Tid
    RecordKey -> types.RecordKey
  }

  case formats.validate_format(value, types_format) {
    True -> Ok(Nil)
    False -> {
      let format_name = types.format_to_string(types_format)
      Error("Value does not match format: " <> format_name)
    }
  }
}

/// Entry point for the honk lexicon validator.
///
/// This function serves as an example entry point and can be used
/// for basic CLI or testing purposes. For actual validation,
/// use the `validate()` or `validate_record()` functions.
///
/// ## Example
///
/// ```gleam
/// import honk
///
/// pub fn main() {
///   honk.main()
/// }
/// ```
pub fn main() -> Nil {
  // This would typically be called from tests or CLI
  let _example_result = is_valid_nsid("com.example.record")
  Nil
}
