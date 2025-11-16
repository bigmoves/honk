import gleam/json
import gleeunit
import gleeunit/should
import honk

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
  honk.validate_string_format("2024-01-01T12:00:00Z", honk.DateTime)
  |> should.be_ok

  honk.validate_string_format("not a datetime", honk.DateTime)
  |> should.be_error

  honk.validate_string_format("https://example.com", honk.Uri)
  |> should.be_ok
}
