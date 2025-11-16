// Validation context and builder

import errors.{type ValidationError}
import gleam/dict.{type Dict}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}
import gleam/string
import json_helpers
import types.{type LexiconDoc, LexiconDoc}
import validation/formats

/// Validation context that tracks state during validation
pub type ValidationContext {
  ValidationContext(
    // Map of lexicon ID to parsed lexicon document
    lexicons: Dict(String, LexiconDoc),
    // Current path in data structure (for error messages)
    path: String,
    // Current lexicon ID (for resolving local references)
    current_lexicon_id: Option(String),
    // Set of references being resolved (for circular detection)
    reference_stack: Set(String),
    // Recursive validator function for dispatching to type-specific validators
    // Parameters: data (Json), schema (Json), ctx (ValidationContext)
    validator: fn(Json, Json, ValidationContext) -> Result(Nil, ValidationError),
  )
}

/// Builder for constructing ValidationContext
pub type ValidationContextBuilder {
  ValidationContextBuilder(
    lexicons: Dict(String, LexiconDoc),
    // Parameters: data (Json), schema (Json), ctx (ValidationContext)
    validator: Option(
      fn(Json, Json, ValidationContext) -> Result(Nil, ValidationError),
    ),
  )
}

/// Creates a new ValidationContextBuilder with default settings.
///
/// Use this to start building a validation context by chaining with
/// `with_lexicons`, `with_validator`, and `build`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ctx) =
///   context.builder()
///   |> context.with_validator(field.dispatch_data_validation)
///   |> context.with_lexicons([my_lexicon])
///   |> context.build
/// ```
pub fn builder() -> ValidationContextBuilder {
  ValidationContextBuilder(lexicons: dict.new(), validator: None)
}

/// Adds a list of lexicon JSON documents to the builder.
///
/// Each lexicon must have an 'id' field (valid NSID) and a 'defs' object
/// containing type definitions. Returns an error if any lexicon is invalid.
///
/// ## Example
///
/// ```gleam
/// let lexicon = json.object([
///   #("lexicon", json.int(1)),
///   #("id", json.string("com.example.post")),
///   #("defs", json.object([...])),
/// ])
///
/// let assert Ok(builder) =
///   context.builder()
///   |> context.with_lexicons([lexicon])
/// ```
pub fn with_lexicons(
  builder: ValidationContextBuilder,
  lexicons: List(Json),
) -> Result(ValidationContextBuilder, ValidationError) {
  // Parse each lexicon and add to the dictionary
  list.try_fold(lexicons, builder, fn(b, lex_json) {
    // Extract id and defs from the lexicon JSON
    case parse_lexicon(lex_json) {
      Ok(lexicon_doc) -> {
        let updated_lexicons =
          dict.insert(b.lexicons, lexicon_doc.id, lexicon_doc)
        Ok(ValidationContextBuilder(..b, lexicons: updated_lexicons))
      }
      Error(e) -> Error(e)
    }
  })
}

/// Set the validator function
/// Parameters: data (Json), schema (Json), ctx (ValidationContext)
pub fn with_validator(
  builder: ValidationContextBuilder,
  validator: fn(Json, Json, ValidationContext) -> Result(Nil, ValidationError),
) -> ValidationContextBuilder {
  ValidationContextBuilder(..builder, validator: Some(validator))
}

/// Builds the final ValidationContext from the builder.
///
/// Creates a no-op validator if none was set via `with_validator`.
/// Returns a ValidationContext ready for validating lexicons and data.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ctx) =
///   context.builder()
///   |> context.with_validator(field.dispatch_data_validation)
///   |> context.with_lexicons([lexicon])
///   |> context.build
/// ```
pub fn build(
  builder: ValidationContextBuilder,
) -> Result(ValidationContext, ValidationError) {
  // Create a default no-op validator if none is set
  let validator = case builder.validator {
    Some(v) -> v
    None -> fn(_data, _schema, _ctx) { Ok(Nil) }
  }

  Ok(ValidationContext(
    lexicons: builder.lexicons,
    path: "",
    current_lexicon_id: None,
    reference_stack: set.new(),
    validator: validator,
  ))
}

/// Retrieves a lexicon document by its NSID from the validation context.
///
/// Returns `None` if the lexicon is not found. Use this to access
/// lexicon definitions when resolving references.
///
/// ## Example
///
/// ```gleam
/// case context.get_lexicon(ctx, "com.example.post") {
///   Some(lexicon) -> // Use the lexicon
///   None -> // Lexicon not found
/// }
/// ```
pub fn get_lexicon(ctx: ValidationContext, id: String) -> Option(LexiconDoc) {
  case dict.get(ctx.lexicons, id) {
    Ok(lex) -> Some(lex)
    Error(_) -> None
  }
}

/// Returns the current validation path within the data structure.
///
/// The path is used for generating detailed error messages that show
/// exactly where in a nested structure validation failed.
///
/// ## Example
///
/// ```gleam
/// let current_path = context.path(ctx)
/// // Returns something like "defs.post.properties.text"
/// ```
pub fn path(ctx: ValidationContext) -> String {
  ctx.path
}

/// Creates a new context with an updated path segment.
///
/// Used when traversing nested data structures during validation
/// to maintain accurate error location information.
///
/// ## Example
///
/// ```gleam
/// let nested_ctx = context.with_path(ctx, "properties.name")
/// // New path might be "defs.user.properties.name"
/// ```
pub fn with_path(ctx: ValidationContext, segment: String) -> ValidationContext {
  let new_path = case ctx.path {
    "" -> segment
    _ -> ctx.path <> "." <> segment
  }
  ValidationContext(..ctx, path: new_path)
}

/// Returns the ID of the lexicon currently being validated.
///
/// Used for resolving local references (e.g., `#post`) which need to
/// know which lexicon they belong to.
///
/// ## Example
///
/// ```gleam
/// case context.current_lexicon_id(ctx) {
///   Some(id) -> // id is like "com.example.post"
///   None -> // No lexicon context set
/// }
/// ```
pub fn current_lexicon_id(ctx: ValidationContext) -> Option(String) {
  ctx.current_lexicon_id
}

/// Creates a new context with a different current lexicon ID.
///
/// Used when validating cross-lexicon references to set the correct
/// lexicon context for resolving local references.
///
/// ## Example
///
/// ```gleam
/// let ctx_with_lexicon =
///   context.with_current_lexicon(ctx, "com.example.post")
/// ```
pub fn with_current_lexicon(
  ctx: ValidationContext,
  lexicon_id: String,
) -> ValidationContext {
  ValidationContext(..ctx, current_lexicon_id: Some(lexicon_id))
}

/// Adds a reference to the reference stack for circular dependency detection.
///
/// Used internally during reference resolution to track which references
/// are currently being validated. This prevents infinite loops when
/// references form a cycle.
///
/// ## Example
///
/// ```gleam
/// let ctx_with_ref =
///   context.with_reference(ctx, "com.example.post#user")
/// ```
pub fn with_reference(
  ctx: ValidationContext,
  reference: String,
) -> ValidationContext {
  ValidationContext(
    ..ctx,
    reference_stack: set.insert(ctx.reference_stack, reference),
  )
}

/// Checks if a reference is already in the reference stack.
///
/// Returns `True` if the reference is being validated, indicating a
/// circular reference that would cause infinite recursion. Used to
/// detect and prevent circular dependency errors.
///
/// ## Example
///
/// ```gleam
/// case context.has_reference(ctx, "#user") {
///   True -> Error(errors.data_validation("Circular reference detected"))
///   False -> // Safe to proceed with validation
/// }
/// ```
pub fn has_reference(ctx: ValidationContext, reference: String) -> Bool {
  set.contains(ctx.reference_stack, reference)
}

/// Parse a reference string into (lexicon_id, definition)
/// Handles: #def, nsid#def, nsid
pub fn parse_reference(
  ctx: ValidationContext,
  reference: String,
) -> Result(#(String, String), ValidationError) {
  case string.split(reference, "#") {
    // Local reference: #def
    ["", def] ->
      case ctx.current_lexicon_id {
        Some(lex_id) -> Ok(#(lex_id, def))
        None ->
          Error(errors.invalid_schema(
            "Local reference '"
            <> reference
            <> "' used without current lexicon context",
          ))
      }
    // Global reference: nsid#def
    [nsid, def] if nsid != "" && def != "" -> Ok(#(nsid, def))
    // Global main: nsid (implicit #main)
    [nsid] if nsid != "" -> Ok(#(nsid, "main"))
    // Invalid
    _ -> Error(errors.invalid_schema("Invalid reference format: " <> reference))
  }
}

/// Helper to parse a lexicon JSON into LexiconDoc
fn parse_lexicon(lex_json: Json) -> Result(LexiconDoc, ValidationError) {
  // Extract "id" field (required NSID)
  let id_result = case json_helpers.get_string(lex_json, "id") {
    Some(id) -> Ok(id)
    None -> Error(errors.invalid_schema("Lexicon missing required 'id' field"))
  }

  use id <- result.try(id_result)

  // Validate that id is a valid NSID
  use _ <- result.try(case formats.is_valid_nsid(id) {
    True -> Ok(Nil)
    False ->
      Error(errors.invalid_schema(
        "Lexicon 'id' field is not a valid NSID: " <> id,
      ))
  })

  // Extract "defs" field (required object containing definitions)
  let defs_result = case json_helpers.get_field(lex_json, "defs") {
    Some(defs) ->
      case json_helpers.is_object(defs) {
        True -> Ok(defs)
        False ->
          Error(errors.invalid_schema(
            "Lexicon 'defs' must be an object at " <> id,
          ))
      }
    None ->
      Error(errors.invalid_schema(
        "Lexicon missing required 'defs' field at " <> id,
      ))
  }

  use defs <- result.try(defs_result)

  Ok(LexiconDoc(id: id, defs: defs))
}
