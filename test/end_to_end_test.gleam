import gleam/dict
import gleam/json
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import honk
import honk/types.{DateTime, Uri}

pub fn main() {
  gleeunit.main()
}

// Test complete lexicon validation
pub fn validate_complete_lexicon_test() {
  // Create a complete lexicon for a blog post record
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.bsky.feed.post")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("record")),
              #("key", json.string("tid")),
              #(
                "record",
                json.object([
                  #("type", json.string("object")),
                  #("required", json.array([json.string("text")], fn(x) { x })),
                  #(
                    "properties",
                    json.object([
                      #(
                        "text",
                        json.object([
                          #("type", json.string("string")),
                          #("maxLength", json.int(300)),
                          #("maxGraphemes", json.int(300)),
                        ]),
                      ),
                      #(
                        "createdAt",
                        json.object([
                          #("type", json.string("string")),
                          #("format", json.string("datetime")),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let result = honk.validate([lexicon])
  result |> should.be_ok
}

// Test invalid lexicon (missing id)
pub fn validate_invalid_lexicon_missing_id_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("record")),
              #("key", json.string("tid")),
              #(
                "record",
                json.object([
                  #("type", json.string("object")),
                  #("properties", json.object([])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let result = honk.validate([lexicon])
  result |> should.be_error
}

// Test validate_record with valid data
pub fn validate_record_data_valid_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.bsky.feed.post")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("record")),
              #("key", json.string("tid")),
              #(
                "record",
                json.object([
                  #("type", json.string("object")),
                  #("required", json.array([json.string("text")], fn(x) { x })),
                  #(
                    "properties",
                    json.object([
                      #(
                        "text",
                        json.object([
                          #("type", json.string("string")),
                          #("maxLength", json.int(300)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let record_data = json.object([#("text", json.string("Hello, ATProtocol!"))])

  let result =
    honk.validate_record([lexicon], "app.bsky.feed.post", record_data)
  result |> should.be_ok
}

// Test validate_record with invalid data (missing required field)
pub fn validate_record_data_missing_required_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.bsky.feed.post")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("record")),
              #("key", json.string("tid")),
              #(
                "record",
                json.object([
                  #("type", json.string("object")),
                  #("required", json.array([json.string("text")], fn(x) { x })),
                  #(
                    "properties",
                    json.object([
                      #(
                        "text",
                        json.object([
                          #("type", json.string("string")),
                          #("maxLength", json.int(300)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let record_data =
    json.object([#("description", json.string("No text field"))])

  let result =
    honk.validate_record([lexicon], "app.bsky.feed.post", record_data)
  result |> should.be_error
}

// Test NSID validation helper
pub fn is_valid_nsid_test() {
  honk.is_valid_nsid("app.bsky.feed.post") |> should.be_true
  honk.is_valid_nsid("com.example.foo") |> should.be_true
  honk.is_valid_nsid("invalid") |> should.be_false
  honk.is_valid_nsid("") |> should.be_false
}

// Test string format validation helper
pub fn validate_string_format_test() {
  honk.validate_string_format("2024-01-01T12:00:00Z", DateTime)
  |> should.be_ok

  honk.validate_string_format("not a datetime", DateTime)
  |> should.be_error

  honk.validate_string_format("https://example.com", Uri)
  |> should.be_ok
}

// Test lexicon with multiple valid definitions
pub fn validate_lexicon_multiple_defs_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.multi")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("record")),
              #("key", json.string("tid")),
              #(
                "record",
                json.object([
                  #("type", json.string("object")),
                  #("properties", json.object([])),
                ]),
              ),
            ]),
          ),
          #(
            "stringFormats",
            json.object([
              #("type", json.string("object")),
              #("properties", json.object([])),
            ]),
          ),
          #("additionalType", json.object([#("type", json.string("string"))])),
        ]),
      ),
    ])

  honk.validate([lexicon])
  |> should.be_ok
}

// Test lexicon with only non-main definitions
pub fn validate_lexicon_no_main_def_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.nomain")),
      #(
        "defs",
        json.object([
          #("customType", json.object([#("type", json.string("string"))])),
          #("anotherType", json.object([#("type", json.string("integer"))])),
        ]),
      ),
    ])

  honk.validate([lexicon])
  |> should.be_ok
}

// Test lexicon with invalid non-main definition
pub fn validate_lexicon_invalid_non_main_def_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.invalid")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("record")),
              #("key", json.string("tid")),
              #(
                "record",
                json.object([
                  #("type", json.string("object")),
                  #("properties", json.object([])),
                ]),
              ),
            ]),
          ),
          #(
            "badDef",
            json.object([
              #("type", json.string("string")),
              #("minLength", json.int(10)),
              #("maxLength", json.int(5)),
            ]),
          ),
        ]),
      ),
    ])

  case honk.validate([lexicon]) {
    Error(error_map) -> {
      // Should have error for this lexicon
      case dict.get(error_map, "com.example.invalid") {
        Ok(errors) -> {
          // Error message should include the def name
          list.any(errors, fn(msg) { string.contains(msg, "#badDef") })
          |> should.be_true
        }
        Error(_) -> panic as "Expected error for com.example.invalid"
      }
    }
    Ok(_) -> panic as "Expected validation to fail"
  }
}

// Test empty defs object
pub fn validate_lexicon_empty_defs_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.empty")),
      #("defs", json.object([])),
    ])

  honk.validate([lexicon])
  |> should.be_ok
}
