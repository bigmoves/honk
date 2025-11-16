# Jetstream Validation Example

This example demonstrates using **honk** to validate AT Protocol records from Bluesky's Jetstream firehose in real-time.

## What it does

1. Connects to Jetstream using **goose** (WebSocket consumer)
2. Filters for `xyz.statusphere.status` records
3. Validates each record using **honk**
4. Displays validation results with emoji status

## Running the example

```sh
cd example
gleam run
```

The example will connect to the live Jetstream firehose and display validation results as records are created:

```
🦢 Honk + Goose: Jetstream Validation Example
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Connecting to Jetstream...
Filtering for: xyz.statusphere.status
Validating records with honk...

✓ VALID   | q6gjnaw2blty... | 👍 | 3l4abc123
✓ VALID   | wa7b35aakoll... | 🎉 | 3l4def456
✗ INVALID | rfov6bpyztcn... | Data: status exceeds maxGraphemes | 3l4ghi789
✓ UPDATED | eygmaihciaxp... | 😀 | 3l4jkl012
🗑️  DELETED | ufbl4k27gp6k... | 3l4mno345
```

## How it works

### Lexicon Definition

The example defines the `xyz.statusphere.status` lexicon:

```json
{
  "lexicon": 1,
  "id": "xyz.statusphere.status",
  "defs": {
    "main": {
      "type": "record",
      "record": {
        "type": "object",
        "required": ["status", "createdAt"],
        "properties": {
          "status": {
            "type": "string",
            "minLength": 1,
            "maxGraphemes": 1,
            "maxLength": 32
          },
          "createdAt": {
            "type": "string",
            "format": "datetime"
          }
        }
      }
    }
  }
}
```

### Validation Flow

1. **goose** receives Jetstream events via WebSocket
2. Events are parsed into typed Gleam structures
3. For `create` and `update` operations:
   - Extract the `record` field (contains the status data)
   - Pass to `honk.validate_record()` with the lexicon
   - Display ✓ for valid or ✗ for invalid records
4. For `delete` operations:
   - Just log the deletion (no record to validate)

### Dependencies

- **honk**: AT Protocol lexicon validator (local path)
- **goose**: Jetstream WebSocket consumer library
- **gleam_json**: JSON encoding/decoding
- **gleam_stdlib**: Standard library

## Code Structure

```
example/
├── gleam.toml          # Dependencies configuration
├── README.md           # This file
└── src/
    └── example.gleam   # Main application
        ├── main()                      # Entry point
        ├── handle_event()              # Process Jetstream events
        ├── handle_create/update()      # Validate records
        ├── create_statusphere_lexicon()# Define lexicon
        └── format_error/extract_status # Display helpers
```

## Learn More

- **honk**: https://hexdocs.pm/honk
- **goose**: https://hexdocs.pm/goose
- **Jetstream**: https://docs.bsky.app/docs/advanced-guides/jetstream
- **AT Protocol**: https://atproto.com/
