// Example: Validating xyz.statusphere.status records from Jetstream using honk
//
// This example connects to Bluesky's Jetstream firehose, filters for
// xyz.statusphere.status records, and validates them in real-time using honk.

import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/option
import gleam/string
import goose
import honk
import honk/errors.{DataValidation, InvalidSchema, LexiconNotFound}

pub fn main() {
  io.println("🦢 Honk + Goose: Jetstream Validation Example")
  io.println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
  io.println("")
  io.println("Connecting to Jetstream...")
  io.println("Filtering for: xyz.statusphere.status")
  io.println("Validating records with honk...")
  io.println("")

  // Define the xyz.statusphere.status lexicon
  let lexicon = create_statusphere_lexicon()

  // Configure goose to connect to Jetstream
  let config =
    goose.JetstreamConfig(
      endpoint: "wss://jetstream2.us-west.bsky.network/subscribe",
      wanted_collections: ["xyz.statusphere.status"],
      wanted_dids: [],
      cursor: option.None,
      max_message_size_bytes: option.None,
      compress: True,
      require_hello: False,
    )

  // Start consuming events (this blocks forever)
  goose.start_consumer(config, handle_event(_, lexicon))
}

/// Handles each Jetstream event
fn handle_event(json_event: String, lexicon: json.Json) -> Nil {
  let event = goose.parse_event(json_event)

  case event {
    // Handle commit events (create/update/delete)
    goose.CommitEvent(did, time_us, commit) -> {
      case commit.operation {
        "create" -> handle_create(did, time_us, commit, lexicon)
        "update" -> handle_update(did, time_us, commit, lexicon)
        "delete" -> handle_delete(did, time_us, commit)
        _ -> Nil
      }
    }

    // Ignore identity and account events for this example
    goose.IdentityEvent(_, _, _) -> Nil
    goose.AccountEvent(_, _, _) -> Nil
    goose.UnknownEvent(raw) -> {
      io.println("⚠️  Unknown event: " <> raw)
    }
  }
}

/// Handles create operations - validates the new record
fn handle_create(
  did: String,
  _time_us: Int,
  commit: goose.CommitData,
  lexicon: json.Json,
) -> Nil {
  case commit.record {
    option.Some(record_dynamic) -> {
      // Convert Dynamic to JSON for honk validation
      let record_json = dynamic_to_json(record_dynamic)

      // Validate the record using honk
      case
        honk.validate_record([lexicon], "xyz.statusphere.status", record_json)
      {
        Ok(_) -> {
          // Extract status emoji for display
          let status_emoji = extract_status(record_dynamic)
          io.println(
            "✓ VALID   | "
            <> truncate_did(did)
            <> " | "
            <> status_emoji
            <> " | "
            <> commit.rkey,
          )
        }
        Error(err) -> {
          io.println(
            "✗ INVALID | "
            <> truncate_did(did)
            <> " | "
            <> format_error(err)
            <> " | "
            <> commit.rkey,
          )
        }
      }
    }
    option.None -> {
      io.println("⚠️  CREATE event without record data")
    }
  }
}

/// Handles update operations - validates the updated record
fn handle_update(
  did: String,
  _time_us: Int,
  commit: goose.CommitData,
  lexicon: json.Json,
) -> Nil {
  case commit.record {
    option.Some(record_dynamic) -> {
      let record_json = dynamic_to_json(record_dynamic)

      case
        honk.validate_record([lexicon], "xyz.statusphere.status", record_json)
      {
        Ok(_) -> {
          let status_emoji = extract_status(record_dynamic)
          io.println(
            "✓ UPDATED | "
            <> truncate_did(did)
            <> " | "
            <> status_emoji
            <> " | "
            <> commit.rkey,
          )
        }
        Error(err) -> {
          io.println(
            "✗ INVALID | "
            <> truncate_did(did)
            <> " | "
            <> format_error(err)
            <> " | "
            <> commit.rkey,
          )
        }
      }
    }
    option.None -> {
      io.println("⚠️  UPDATE event without record data")
    }
  }
}

/// Handles delete operations - no validation needed
fn handle_delete(did: String, _time_us: Int, commit: goose.CommitData) -> Nil {
  io.println("🗑️  DELETED | " <> truncate_did(did) <> " | " <> commit.rkey)
}

/// Creates the xyz.statusphere.status lexicon definition
fn create_statusphere_lexicon() -> json.Json {
  json.object([
    #("lexicon", json.int(1)),
    #("id", json.string("xyz.statusphere.status")),
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
                  "required",
                  json.preprocessed_array([
                    json.string("status"),
                    json.string("createdAt"),
                  ]),
                ),
                #(
                  "properties",
                  json.object([
                    #(
                      "status",
                      json.object([
                        #("type", json.string("string")),
                        #("minLength", json.int(1)),
                        #("maxGraphemes", json.int(1)),
                        #("maxLength", json.int(32)),
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
}

/// Converts Dynamic to Json (they're the same underlying type)
@external(erlang, "gleam@dynamic", "unsafe_coerce")
fn dynamic_to_json(value: decode.Dynamic) -> json.Json

/// Extracts the status emoji from a record for display
fn extract_status(record: decode.Dynamic) -> String {
  let decoder = {
    use status <- decode.field("status", decode.string)
    decode.success(status)
  }
  case decode.run(record, decoder) {
    Ok(status) -> status
    Error(_) -> "�"
  }
}

/// Formats a validation error for display
fn format_error(err: honk.ValidationError) -> String {
  case err {
    InvalidSchema(msg) -> "Schema: " <> msg
    DataValidation(msg) -> "Data: " <> msg
    LexiconNotFound(id) -> "Not found: " <> id
  }
}

/// Truncates a DID for cleaner display
fn truncate_did(did: String) -> String {
  case string.split(did, ":") {
    [_, _, suffix] ->
      case string.length(suffix) > 12 {
        True -> string.slice(suffix, 0, 12) <> "..."
        False -> suffix
      }
    _ -> did
  }
}
