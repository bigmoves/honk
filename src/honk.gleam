// Main public API for the ATProtocol lexicon validator

import argv
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json.{type Json}
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import honk/errors
import honk/internal/json_helpers
import honk/types
import honk/validation/context
import honk/validation/formats
import simplifile

// Import validators
import honk/validation/field as validation_field
import honk/validation/field/reference as validation_field_reference
import honk/validation/field/union as validation_field_union
import honk/validation/meta/token as validation_meta_token
import honk/validation/meta/unknown as validation_meta_unknown
import honk/validation/primary/params as validation_primary_params
import honk/validation/primary/procedure as validation_primary_procedure
import honk/validation/primary/query as validation_primary_query
import honk/validation/primary/record as validation_primary_record
import honk/validation/primary/subscription as validation_primary_subscription
import honk/validation/primitive/blob as validation_primitive_blob
import honk/validation/primitive/boolean as validation_primitive_boolean
import honk/validation/primitive/bytes as validation_primitive_bytes
import honk/validation/primitive/cid_link as validation_primitive_cid_link
import honk/validation/primitive/integer as validation_primitive_integer
import honk/validation/primitive/null as validation_primitive_null
import honk/validation/primitive/string as validation_primitive_string

// Re-export error type for public API error handling
pub type ValidationError =
  errors.ValidationError

/// Validates lexicon documents
///
/// Validates lexicon structure (id, defs) and ALL definitions within each lexicon.
/// Each definition in the defs object is validated according to its type.
///
/// Returns Ok(Nil) if all lexicons and their definitions are valid.
/// Returns Error with a map of lexicon ID to list of error messages.
/// Error messages include the definition name (e.g., "lex.id#defName: error").
pub fn validate(lexicons: List(Json)) -> Result(Nil, Dict(String, List(String))) {
  // Build validation context
  let builder_result =
    context.builder()
    |> context.with_lexicons(lexicons)

  case builder_result {
    Ok(builder) ->
      case context.build(builder) {
        Ok(ctx) -> {
          // Validate ALL definitions in each lexicon
          let error_map =
            dict.fold(ctx.lexicons, dict.new(), fn(errors, lex_id, lexicon) {
              // Get all definition names from the defs object
              let def_keys = json_helpers.get_keys(lexicon.defs)
              let lex_ctx = context.with_current_lexicon(ctx, lex_id)

              // Validate each definition
              list.fold(def_keys, errors, fn(errors_acc, def_name) {
                case json_helpers.get_field(lexicon.defs, def_name) {
                  Some(def) -> {
                    case validate_definition(def, lex_ctx) {
                      Ok(_) -> errors_acc
                      Error(e) -> {
                        // Include def name in error for better context
                        // Extract just the message without wrapper text
                        let message = case e {
                          errors.InvalidSchema(msg) -> msg
                          errors.DataValidation(msg) -> msg
                          errors.LexiconNotFound(msg) -> "Lexicon not found: " <> msg
                        }
                        // Clean up leading ": " if present
                        let clean_message = case string.starts_with(message, ": ") {
                          True -> string.drop_start(message, 2)
                          False -> message
                        }
                        let error_msg = lex_id <> "#" <> def_name <> ": " <> clean_message
                        case dict.get(errors_acc, lex_id) {
                          Ok(existing_errors) ->
                            dict.insert(errors_acc, lex_id, [
                              error_msg,
                              ..existing_errors
                            ])
                          Error(_) ->
                            dict.insert(errors_acc, lex_id, [error_msg])
                        }
                      }
                    }
                  }
                  None -> errors_acc
                }
              })
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
  format: types.StringFormat,
) -> Result(Nil, String) {
  case formats.validate_format(value, format) {
    True -> Ok(Nil)
    False -> {
      let format_name = types.format_to_string(format)
      Error("Value does not match format: " <> format_name)
    }
  }
}

/// CLI entry point for the honk lexicon validator
///
/// Usage:
///   gleam run -m honk check <path>
///   gleam run -m honk help
pub fn main() -> Nil {
  case argv.load().arguments {
    ["check", path] -> validate_path(path)
    ["help"] | [] -> show_help()
    _ -> {
      io.println_error("Unknown command. Use 'help' for usage information.")
      Nil
    }
  }
}

/// Validate a path (auto-detects file or directory)
fn validate_path(path: String) -> Nil {
  case simplifile.is_file(path) {
    Ok(True) -> validate_file(path)
    Ok(False) ->
      case simplifile.is_directory(path) {
        Ok(True) -> validate_directory(path)
        Ok(False) -> {
          io.println_error("Error: Path is neither a file nor a directory: " <> path)
          Nil
        }
        Error(_) -> {
          io.println_error("Error: Cannot access path: " <> path)
          Nil
        }
      }
    Error(_) -> {
      io.println_error("Error: Cannot access path: " <> path)
      Nil
    }
  }
}

/// Validate a single lexicon file
fn validate_file(file_path: String) -> Nil {
  case read_and_validate_file(file_path) {
    Ok(_) -> {
      io.println("✓ " <> file_path <> " - valid")
      Nil
    }
    Error(msg) -> {
      io.println_error("✗ " <> file_path)
      io.println_error("  " <> msg)
      Nil
    }
  }
}

/// Validate all .json files in a directory
fn validate_directory(dir_path: String) -> Nil {
  case simplifile.get_files(dir_path) {
    Error(_) -> {
      io.println_error("Error: Cannot read directory: " <> dir_path)
      Nil
    }
    Ok(all_files) -> {
      // Filter for .json files
      let json_files =
        all_files
        |> list.filter(fn(path) { string.ends_with(path, ".json") })

      case json_files {
        [] -> {
          io.println("No .json files found in " <> dir_path)
          Nil
        }
        files -> {
          // Read and parse all files
          let file_results =
            files
            |> list.map(fn(file) {
              case read_json_file(file) {
                Ok(json_value) -> #(file, Ok(json_value))
                Error(msg) -> #(file, Error(msg))
              }
            })

          // Separate successful parses from failures
          let #(parse_errors, parsed_files) =
            list.partition(file_results, fn(result) {
              case result {
                #(_, Error(_)) -> True
                #(_, Ok(_)) -> False
              }
            })

          // Display parse errors
          parse_errors
          |> list.each(fn(result) {
            case result {
              #(file, Error(msg)) -> {
                io.println_error("✗ " <> file)
                io.println_error("  " <> msg)
              }
              _ -> Nil
            }
          })

          // Get all successfully parsed lexicons
          let lexicons =
            parsed_files
            |> list.filter_map(fn(result) {
              case result {
                #(_, Ok(json)) -> Ok(json)
                _ -> Error(Nil)
              }
            })

          // Validate all lexicons together (allows cross-lexicon references)
          case validate(lexicons) {
            Ok(_) -> {
              // All lexicons are valid
              parsed_files
              |> list.each(fn(result) {
                case result {
                  #(file, Ok(_)) -> io.println("✓ " <> file)
                  _ -> Nil
                }
              })
            }
            Error(error_map) -> {
              // Some lexicons have errors - map errors back to files
              parsed_files
              |> list.each(fn(result) {
                case result {
                  #(file, Ok(json)) -> {
                    // Get the lexicon ID for this file
                    case json_helpers.get_string(json, "id") {
                      Some(lex_id) -> {
                        case dict.get(error_map, lex_id) {
                          Ok(errors) -> {
                            io.println_error("✗ " <> file)
                            errors
                            |> list.each(fn(err) {
                              io.println_error("  " <> err)
                            })
                          }
                          Error(_) -> io.println("✓ " <> file)
                        }
                      }
                      None -> {
                        io.println_error("✗ " <> file)
                        io.println_error("  Missing lexicon id")
                      }
                    }
                  }
                  _ -> Nil
                }
              })
            }
          }

          // Summary
          let total = list.length(files)
          let parse_error_count = list.length(parse_errors)
          let validation_error_count = case validate(lexicons) {
            Ok(_) -> 0
            Error(error_map) -> dict.size(error_map)
          }
          let total_errors = parse_error_count + validation_error_count

          case total_errors {
            0 ->
              io.println(
                "\nAll " <> int.to_string(total) <> " schemas validated successfully.",
              )
            _ ->
              io.println_error(
                "\n"
                <> int.to_string(total_errors)
                <> " of "
                <> int.to_string(total)
                <> " schemas failed validation.",
              )
          }

          Nil
        }
      }
    }
  }
}

/// Read and parse a JSON file (without validation)
fn read_json_file(file_path: String) -> Result(Json, String) {
  use content <- result.try(
    simplifile.read(file_path)
    |> result.map_error(fn(_) { "Cannot read file" }),
  )

  use json_dynamic <- result.try(
    json.parse(content, decode.dynamic)
    |> result.map_error(fn(_) { "Invalid JSON" }),
  )

  json_helpers.dynamic_to_json(json_dynamic)
  |> result.map_error(fn(_) { "Failed to convert JSON" })
}

/// Read a file and validate it as a lexicon
fn read_and_validate_file(file_path: String) -> Result(Nil, String) {
  use content <- result.try(
    simplifile.read(file_path)
    |> result.map_error(fn(_) { "Cannot read file" }),
  )

  use json_dynamic <- result.try(
    json.parse(content, decode.dynamic)
    |> result.map_error(fn(_) { "Invalid JSON" }),
  )

  use json_value <- result.try(
    json_helpers.dynamic_to_json(json_dynamic)
    |> result.map_error(fn(_) { "Failed to convert JSON" }),
  )

  use _ <- result.try(
    validate([json_value])
    |> result.map_error(fn(error_map) { format_validation_errors(error_map) }),
  )

  Ok(Nil)
}

/// Format validation errors from the error map
fn format_validation_errors(error_map: Dict(String, List(String))) -> String {
  error_map
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(_key, errors) = entry
    string.join(errors, "\n  ")
  })
  |> string.join("\n  ")
}

/// Show help text
fn show_help() -> Nil {
  io.println(
    "
honk - ATProtocol Lexicon Validator

USAGE:
  gleam run -m honk check <path>
  gleam run -m honk help

COMMANDS:
  check <path>     Check a lexicon file or directory
                   - If <path> is a file: validates that single lexicon
                   - If <path> is a directory: recursively validates all .json files

  help            Show this help message

EXAMPLES:
  gleam run -m honk check ./lexicons/xyz/statusphere/status.json
  gleam run -m honk check ./lexicons

VALIDATION:
  - Validates lexicon structure (id, defs)
  - Validates ALL definitions in each lexicon
  - Checks types, constraints, and references
  - Reports errors with definition context (lex.id#defName)
",
  )
}
