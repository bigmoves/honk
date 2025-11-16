# honk

[![Package Version](https://img.shields.io/hexpm/v/honk)](https://hex.pm/packages/honk)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/honk/)

An ATProto Lexicon validator for Gleam.

## What is it?

**honk** validates [AT Protocol](https://atproto.com/) lexicon schemas and data against those schemas. Lexicons are the schema language used by the AT Protocol to define record types, XRPC endpoints, and data structures.

## Installation

```sh
gleam add honk@1
```

## Quick Start

### Validate a Lexicon Schema

```gleam
import honk
import gleam/json

pub fn main() {
  let lexicon = json.object([
    #("lexicon", json.int(1)),
    #("id", json.string("xyz.statusphere.status")),
    #("defs", json.object([
      #("main", json.object([
        #("type", json.string("record")),
        #("key", json.string("tid")),
        #("record", json.object([
          #("type", json.string("object")),
          #("required", json.preprocessed_array([
            json.string("status"),
            json.string("createdAt"),
          ])),
          #("properties", json.object([
            #("status", json.object([
              #("type", json.string("string")),
              #("minLength", json.int(1)),
              #("maxGraphemes", json.int(1)),
              #("maxLength", json.int(32)),
            ])),
            #("createdAt", json.object([
              #("type", json.string("string")),
              #("format", json.string("datetime")),
            ])),
          ])),
        ])),
      ])),
    ])),
  ])

  case honk.validate([lexicon]) {
    Ok(_) -> io.println("✓ Lexicon is valid")
    Error(err) -> io.println("✗ Validation failed: " <> err.message)
  }
}
```

### Validate Record Data

```gleam
import honk
import gleam/json

pub fn validate_status() {
  let lexicons = [my_lexicon] // Your lexicon definitions
  let record_data = json.object([
    #("status", json.string("👍")),
    #("createdAt", json.string("2025-01-15T12:00:00Z")),
  ])

  case honk.validate_record(lexicons, "xyz.statusphere.status", record_data) {
    Ok(_) -> io.println("✓ Record is valid")
    Error(err) -> io.println("✗ Invalid: " <> err.message)
  }
}
```

## Features

- ✅ **17 Type Validators**: string, integer, boolean, bytes, blob, cid-link, null, object, array, union, ref, record, query, procedure, subscription, token, unknown
- ✅ **12 String Format Validators**: datetime (RFC3339), uri, at-uri, did, handle, at-identifier, nsid, cid, language, tid, record-key
- ✅ **Constraint Validation**: length limits, ranges, enums, required fields
- ✅ **Reference Resolution**: local (`#def`), global (`nsid#def`), and cross-lexicon references
- ✅ **Circular Dependency Detection**: prevents infinite reference loops
- ✅ **Detailed Error Messages**: validation errors with path information

## API Overview

### Main Functions

- `validate(lexicons: List(Json))` - Validates one or more lexicon schemas
- `validate_record(lexicons, nsid, data)` - Validates record data against a schema
- `is_valid_nsid(value)` - Checks if a string is a valid NSID
- `validate_string_format(value, format)` - Validates string against a format

### Context Builder Pattern

```gleam
import validation/context
import validation/field

let assert Ok(ctx) =
  context.builder()
  |> context.with_validator(field.dispatch_data_validation)
  |> context.with_lexicons([lexicon])
  |> context.build
```

## Testing

```sh
gleam test
```

## Implementation

This implementation aligns with the [indigo/atproto/lexicon](https://github.com/bluesky-social/indigo/tree/main/atproto/lexicon) implementation as much as possible, ensuring compatibility with the ATProto specification and ecosystem.

## Documentation

Further documentation can be found at <https://hexdocs.pm/honk>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
gleam build # Build the project
```

## License

Apache 2.0
