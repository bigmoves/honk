# honk

[![Package Version](https://img.shields.io/hexpm/v/honk)](https://hex.pm/packages/honk)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/honk/)

An [AT Protocol](https://atproto.com/) Lexicon validator for Gleam.

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

- **Type Validators**: string, integer, boolean, bytes, blob, cid-link, null, object, array, union, ref, record, query, procedure, subscription, token, unknown
- **String Format Validators**: datetime (RFC3339), uri, at-uri, did, handle, at-identifier, nsid, cid, language, tid, record-key
- **Constraint Validation**: length limits, ranges, enums, required fields
- **Reference Resolution**: local (`#def`), global (`nsid#def`), and cross-lexicon references
- **Detailed Error Messages**: validation errors with path information

## CLI Usage

Validate lexicon files from the command line:

```sh
# Validate a single file
gleam run -m honk check ./lexicons/xyz/statusphere/status.json

# Validate all .json files in a directory
gleam run -m honk check ./lexicons/

# Show help
gleam run -m honk help
```

When validating a directory, all lexicons are loaded together to resolve cross-lexicon references

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
