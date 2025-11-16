// JSON helper utilities for extracting and validating fields

import honk/errors.{type ValidationError, data_validation, invalid_schema}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

/// Parse JSON string to dynamic for decoding
fn json_to_dynamic(json_value: Json) -> Result(Dynamic, String) {
  // Convert JSON to string, then parse it back to dynamic
  let json_str = json.to_string(json_value)
  json.parse(json_str, decode.dynamic)
  |> result.map_error(fn(_) { "Failed to parse JSON" })
}

/// Check if a JSON value is null
pub fn is_null(json_value: Json) -> Bool {
  json.to_string(json_value) == "null"
}

/// Check if a JSON value is a string
pub fn is_string(json_value: Json) -> Bool {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.string) {
        Ok(_) -> True
        Error(_) -> False
      }
    Error(_) -> False
  }
}

/// Check if a JSON value is an integer
pub fn is_int(json_value: Json) -> Bool {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.int) {
        Ok(_) -> True
        Error(_) -> False
      }
    Error(_) -> False
  }
}

/// Check if a JSON value is a boolean
pub fn is_bool(json_value: Json) -> Bool {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.bool) {
        Ok(_) -> True
        Error(_) -> False
      }
    Error(_) -> False
  }
}

/// Check if a JSON value is an array
pub fn is_array(json_value: Json) -> Bool {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.list(decode.dynamic)) {
        Ok(_) -> True
        Error(_) -> False
      }
    Error(_) -> False
  }
}

/// Check if a JSON value is an object
pub fn is_object(json_value: Json) -> Bool {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.dict(decode.string, decode.dynamic)) {
        Ok(_) -> True
        Error(_) -> False
      }
    Error(_) -> False
  }
}

/// Get a string field value from a JSON object
pub fn get_string(json_value: Json, field_name: String) -> Option(String) {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.at([field_name], decode.string)) {
        Ok(value) -> Some(value)
        Error(_) -> None
      }
    Error(_) -> None
  }
}

/// Get an integer field value from a JSON object
pub fn get_int(json_value: Json, field_name: String) -> Option(Int) {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.at([field_name], decode.int)) {
        Ok(value) -> Some(value)
        Error(_) -> None
      }
    Error(_) -> None
  }
}

/// Get a boolean field value from a JSON object
pub fn get_bool(json_value: Json, field_name: String) -> Option(Bool) {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.at([field_name], decode.bool)) {
        Ok(value) -> Some(value)
        Error(_) -> None
      }
    Error(_) -> None
  }
}

/// Get an array field value from a JSON object
pub fn get_array(json_value: Json, field_name: String) -> Option(List(Dynamic)) {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case
        decode.run(dyn, decode.at([field_name], decode.list(decode.dynamic)))
      {
        Ok(value) -> Some(value)
        Error(_) -> None
      }
    Error(_) -> None
  }
}

/// Get all keys from a JSON object
pub fn get_keys(json_value: Json) -> List(String) {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.dict(decode.string, decode.dynamic)) {
        Ok(dict_value) -> dict.keys(dict_value)
        Error(_) -> []
      }
    Error(_) -> []
  }
}

/// Require a string field, returning an error if missing or wrong type
pub fn require_string_field(
  json_value: Json,
  field_name: String,
  def_name: String,
) -> Result(String, ValidationError) {
  case get_string(json_value, field_name) {
    Some(s) -> Ok(s)
    None ->
      Error(invalid_schema(
        def_name <> ": '" <> field_name <> "' must be a string",
      ))
  }
}

/// Require an integer field, returning an error if missing or wrong type
pub fn require_int_field(
  json_value: Json,
  field_name: String,
  def_name: String,
) -> Result(Int, ValidationError) {
  case get_int(json_value, field_name) {
    Some(i) -> Ok(i)
    None ->
      Error(invalid_schema(
        def_name <> ": '" <> field_name <> "' must be an integer",
      ))
  }
}

/// Require an array field, returning an error if missing or wrong type
pub fn require_array_field(
  json_value: Json,
  field_name: String,
  def_name: String,
) -> Result(List(Dynamic), ValidationError) {
  case get_array(json_value, field_name) {
    Some(arr) -> Ok(arr)
    None ->
      Error(invalid_schema(
        def_name <> ": '" <> field_name <> "' must be an array",
      ))
  }
}

/// Get a generic field value from a JSON object (returns Json)
pub fn get_field(json_value: Json, field_name: String) -> Option(Json) {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.at([field_name], decode.dynamic)) {
        Ok(field_dyn) -> {
          // Convert dynamic back to Json
          case dynamic_to_json(field_dyn) {
            Ok(json) -> Some(json)
            Error(_) -> None
          }
        }
        Error(_) -> None
      }
    Error(_) -> None
  }
}

/// Get array from a JSON value that is itself an array (not from a field)
pub fn get_array_from_value(json_value: Json) -> Option(List(Dynamic)) {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.list(decode.dynamic)) {
        Ok(arr) -> Some(arr)
        Error(_) -> None
      }
    Error(_) -> None
  }
}

/// Check if dynamic value is null
pub fn is_null_dynamic(dyn: Dynamic) -> Bool {
  case decode.run(dyn, decode.string) {
    Ok("null") -> True
    _ -> False
  }
}

/// Convert JSON object to a dictionary
pub fn json_to_dict(
  json_value: Json,
) -> Result(Dict(String, Dynamic), ValidationError) {
  case json_to_dynamic(json_value) {
    Ok(dyn) ->
      case decode.run(dyn, decode.dict(decode.string, decode.dynamic)) {
        Ok(dict_val) -> Ok(dict_val)
        Error(_) ->
          Error(data_validation("Failed to convert JSON to dictionary"))
      }
    Error(_) -> Error(data_validation("Failed to parse JSON as dynamic"))
  }
}

/// Convert a dynamic value back to Json
/// This works by trying different decoders
pub fn dynamic_to_json(dyn: Dynamic) -> Result(Json, ValidationError) {
  // Try null
  case decode.run(dyn, decode.string) {
    Ok(s) -> {
      case s {
        "null" -> Ok(json.null())
        _ -> Ok(json.string(s))
      }
    }
    Error(_) -> {
      // Try number
      case decode.run(dyn, decode.int) {
        Ok(i) -> Ok(json.int(i))
        Error(_) -> {
          // Try boolean
          case decode.run(dyn, decode.bool) {
            Ok(b) -> Ok(json.bool(b))
            Error(_) -> {
              // Try array
              case decode.run(dyn, decode.list(decode.dynamic)) {
                Ok(arr) -> {
                  // Recursively convert array items
                  case list.try_map(arr, dynamic_to_json) {
                    Ok(json_arr) -> Ok(json.array(json_arr, fn(x) { x }))
                    Error(e) -> Error(e)
                  }
                }
                Error(_) -> {
                  // Try object
                  case
                    decode.run(dyn, decode.dict(decode.string, decode.dynamic))
                  {
                    Ok(dict_val) -> {
                      // Convert dict to object
                      let pairs = dict.to_list(dict_val)
                      case
                        list.try_map(pairs, fn(pair) {
                          let #(key, value_dyn) = pair
                          case dynamic_to_json(value_dyn) {
                            Ok(value_json) -> Ok(#(key, value_json))
                            Error(e) -> Error(e)
                          }
                        })
                      {
                        Ok(json_pairs) -> Ok(json.object(json_pairs))
                        Error(e) -> Error(e)
                      }
                    }
                    Error(_) ->
                      Error(data_validation(
                        "Failed to convert dynamic to Json",
                      ))
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

/// Type alias for JSON dictionary
pub type JsonDict =
  Dict(String, Dynamic)

/// Create an empty JSON dictionary
pub fn empty_dict() -> JsonDict {
  dict.new()
}

/// Check if a dictionary has a specific key
pub fn dict_has_key(dict_value: JsonDict, key: String) -> Bool {
  case dict.get(dict_value, key) {
    Ok(_) -> True
    Error(_) -> False
  }
}

/// Fold over a dictionary (wrapper around dict.fold)
pub fn dict_fold(
  dict_value: JsonDict,
  initial: acc,
  folder: fn(acc, String, Dynamic) -> acc,
) -> acc {
  dict.fold(dict_value, initial, folder)
}

/// Get a value from a dictionary
pub fn dict_get(dict_value: JsonDict, key: String) -> Option(Dynamic) {
  case dict.get(dict_value, key) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}
