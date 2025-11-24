import gleam/dict
import gleam/json
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import honk
import honk/errors
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

// Test missing required field error message with full defs.main path
pub fn validate_record_missing_required_field_message_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.post")),
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
                  #("required", json.array([json.string("title")], fn(x) { x })),
                  #(
                    "properties",
                    json.object([
                      #(
                        "title",
                        json.object([#("type", json.string("string"))]),
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

  let data = json.object([#("description", json.string("No title"))])

  let assert Error(error) =
    honk.validate_record([lexicon], "com.example.post", data)

  let error_message = errors.to_string(error)
  error_message
  |> should.equal(
    "Data validation failed: defs.main: required field 'title' is missing",
  )
}

// Test missing required field in nested object with full path
pub fn validate_record_nested_missing_required_field_message_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.post")),
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
                  #(
                    "properties",
                    json.object([
                      #(
                        "title",
                        json.object([#("type", json.string("string"))]),
                      ),
                      #(
                        "metadata",
                        json.object([
                          #("type", json.string("object")),
                          #(
                            "required",
                            json.array([json.string("author")], fn(x) { x }),
                          ),
                          #(
                            "properties",
                            json.object([
                              #(
                                "author",
                                json.object([#("type", json.string("string"))]),
                              ),
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
        ]),
      ),
    ])

  let data =
    json.object([
      #("title", json.string("My Post")),
      #("metadata", json.object([#("tags", json.string("tech"))])),
    ])

  let assert Error(error) =
    honk.validate_record([lexicon], "com.example.post", data)

  let error_message = errors.to_string(error)
  error_message
  |> should.equal(
    "Data validation failed: defs.main.metadata: required field 'author' is missing",
  )
}

// Test schema validation error for non-main definition includes correct path
pub fn validate_schema_non_main_definition_error_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.test")),
      #(
        "defs",
        json.object([
          #(
            "objectDef",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #(
                    "fieldA",
                    json.object([
                      #("type", json.string("string")),
                      // Invalid: maxLength must be an integer, not a string
                      #("maxLength", json.string("300")),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          #(
            "recordDef",
            json.object([
              #("type", json.string("record")),
              #("key", json.string("tid")),
              #(
                "record",
                json.object([
                  #("type", json.string("object")),
                  #(
                    "properties",
                    json.object([
                      #(
                        "fieldB",
                        json.object([
                          #("type", json.string("ref")),
                          // Invalid: missing required "ref" field for ref type
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

  // Should have errors
  result |> should.be_error

  case result {
    Error(error_map) -> {
      // Get errors for this lexicon
      case dict.get(error_map, "com.example.test") {
        Ok(error_list) -> {
          // Should have exactly one error from the recordDef (ref missing 'ref' field)
          error_list
          |> should.equal([
            "com.example.test#recordDef: .record.properties.fieldB: ref missing required 'ref' field",
          ])
        }
        Error(_) -> should.fail()
      }
    }
    Ok(_) -> should.fail()
  }
}
