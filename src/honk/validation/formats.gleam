// String format validation

import gleam/list
import gleam/regexp
import gleam/string
import gleam/time/timestamp
import honk/types as types

/// Validates RFC3339 datetime format
pub fn is_valid_rfc3339_datetime(value: String) -> Bool {
  // Max length check (64 chars)
  let len = string.length(value)
  case len == 0 || len > 64 {
    True -> False
    False -> {
      // Stricter RFC3339 regex pattern with restricted digit ranges
      let pattern =
        "^[0-9]{4}-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-6][0-9]:[0-6][0-9](\\.[0-9]{1,20})?(Z|([+-][0-2][0-9]:[0-5][0-9]))$"

      case regexp.from_string(pattern) {
        Ok(re) ->
          case regexp.check(re, value) {
            False -> False
            True -> {
              // Reject -00:00 timezone suffix (must use +00:00 per ISO-8601)
              case string.ends_with(value, "-00:00") {
                True -> False
                False -> {
                  // Attempt actual parsing to validate it's a real datetime
                  case timestamp.parse_rfc3339(value) {
                    Ok(_) -> True
                    Error(_) -> False
                  }
                }
              }
            }
          }
        Error(_) -> False
      }
    }
  }
}

/// Validates URI format
pub fn is_valid_uri(value: String) -> Bool {
  // URI validation with max length and stricter scheme
  // Max length check (8192 chars)
  let len = string.length(value)
  case len == 0 || len > 8192 {
    True -> False
    False -> {
      // Lowercase scheme only, max 81 chars, printable characters after
      // Note: Using [^ \t\n\r\x00-\x1F] for printable/graph chars
      let pattern = "^[a-z][a-z.-]{0,80}:[!-~]+$"
      case regexp.from_string(pattern) {
        Ok(re) -> regexp.check(re, value)
        Error(_) -> False
      }
    }
  }
}

/// Validates AT Protocol URI format (at://did:plc:xxx/collection/rkey)
pub fn is_valid_at_uri(value: String) -> Bool {
  // Max length check (8192 chars)
  let len = string.length(value)
  case len == 0 || len > 8192 {
    True -> False
    False ->
      case string.starts_with(value, "at://") {
        False -> False
        True -> {
          // Pattern: at://authority[/collection[/rkey]]
          let without_scheme = string.drop_start(value, 5)
          case string.split(without_scheme, "/") {
            [authority] -> {
              // Just authority - must be DID or handle
              is_valid_did(authority) || is_valid_handle(authority)
            }
            [authority, collection] -> {
              // Authority + collection - validate both
              case is_valid_did(authority) || is_valid_handle(authority) {
                False -> False
                True -> is_valid_nsid(collection)
              }
            }
            [authority, collection, rkey] -> {
              // Full URI - validate all parts
              case is_valid_did(authority) || is_valid_handle(authority) {
                False -> False
                True ->
                  case is_valid_nsid(collection) {
                    False -> False
                    True -> is_valid_record_key(rkey)
                  }
              }
            }
            _ -> False
          }
        }
      }
  }
}

/// Validates DID format (did:method:identifier)
pub fn is_valid_did(value: String) -> Bool {
  // Max length check (2048 chars)
  let len = string.length(value)
  case len == 0 || len > 2048 {
    True -> False
    False ->
      case string.starts_with(value, "did:") {
        False -> False
        True -> {
          // Pattern ensures identifier ends with valid char (not %)
          let pattern = "^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$"
          case regexp.from_string(pattern) {
            Ok(re) -> regexp.check(re, value)
            Error(_) -> False
          }
        }
      }
  }
}

/// Validates AT Protocol handle (user.bsky.social)
pub fn is_valid_handle(value: String) -> Bool {
  // Handle is a domain name (hostname)
  // Must be lowercase, can have dots, no special chars except hyphen
  // Pattern requires at least one dot and TLD starts with letter
  let pattern =
    "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"

  case
    string.length(value) == 0 || string.length(value) > 253,
    regexp.from_string(pattern)
  {
    True, _ -> False
    False, Ok(re) ->
      case regexp.check(re, value) {
        False -> False
        True -> {
          // Extract TLD and check against disallowed list
          let parts = string.split(value, ".")
          case list.last(parts) {
            Ok(tld) ->
              case tld {
                "local"
                | "arpa"
                | "invalid"
                | "localhost"
                | "internal"
                | "example"
                | "onion"
                | "alt" -> False
                _ -> True
              }
            Error(_) -> False
          }
        }
      }
    False, Error(_) -> False
  }
}

/// Validates AT identifier (either DID or handle)
pub fn is_valid_at_identifier(value: String) -> Bool {
  is_valid_did(value) || is_valid_handle(value)
}

/// Validates NSID format (com.example.type)
pub fn is_valid_nsid(value: String) -> Bool {
  // NSID: reversed domain name with type
  // Pattern: authority.name (e.g., com.example.record)
  let pattern =
    "^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$"

  case regexp.from_string(pattern) {
    Ok(re) -> {
      case regexp.check(re, value) {
        False -> False
        True -> {
          // Must have at least 3 segments and max length 317
          let segments = string.split(value, ".")
          list.length(segments) >= 3 && string.length(value) <= 317
        }
      }
    }
    Error(_) -> False
  }
}

/// Validates CID format (Content Identifier)
pub fn is_valid_cid(value: String) -> Bool {
  // Informal/incomplete helper for fast string verification
  // Aligned with indigo's atproto/syntax/cid.go approach
  // Length: 8-256 chars, alphanumeric plus += characters
  // Rejects CIDv0 starting with "Qmb"
  let len = string.length(value)

  case len < 8 || len > 256 {
    True -> False
    False -> {
      // Reject CIDv0 (not allowed in this version of atproto)
      case string.starts_with(value, "Qmb") {
        True -> False
        False -> {
          // Pattern: alphanumeric plus + and =
          let pattern = "^[a-zA-Z0-9+=]{8,256}$"
          case regexp.from_string(pattern) {
            Ok(re) -> regexp.check(re, value)
            Error(_) -> False
          }
        }
      }
    }
  }
}

/// Validates BCP47 language tag
pub fn is_valid_language_tag(value: String) -> Bool {
  // Lenient BCP47 validation (max 128 chars)
  // Allows: i prefix (IANA), 2-3 letter codes, flexible extensions
  // e.g., en, en-US, zh-Hans-CN, i-enochian
  let len = string.length(value)
  case len == 0 || len > 128 {
    True -> False
    False -> {
      let pattern = "^(i|[a-z]{2,3})(-[a-zA-Z0-9]+)*$"
      case regexp.from_string(pattern) {
        Ok(re) -> regexp.check(re, value)
        Error(_) -> False
      }
    }
  }
}

/// Validates TID format (Timestamp Identifier)
pub fn is_valid_tid(value: String) -> Bool {
  // TID is base32-sortable timestamp (13 characters)
  // First char restricted to ensure valid timestamp range: 234567abcdefghij
  // Remaining 12 chars use full alphabet: 234567abcdefghijklmnopqrstuvwxyz
  let pattern = "^[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}$"

  case string.length(value) == 13, regexp.from_string(pattern) {
    True, Ok(re) -> regexp.check(re, value)
    _, _ -> False
  }
}

/// Validates record key format
pub fn is_valid_record_key(value: String) -> Bool {
  // Record keys can be TIDs or custom strings
  // Custom strings: alphanumeric, dots, dashes, underscores, tildes, colons
  // Length: 1-512 characters
  // Explicitly reject "." and ".." for security
  let len = string.length(value)

  case value == "." || value == ".." {
    True -> False
    False ->
      case len >= 1 && len <= 512 {
        False -> False
        True -> {
          // Check if it's a TID first
          case is_valid_tid(value) {
            True -> True
            False -> {
              // Check custom format (added : to allowed chars)
              let pattern = "^[a-zA-Z0-9_~.:-]+$"
              case regexp.from_string(pattern) {
                Ok(re) -> regexp.check(re, value)
                Error(_) -> False
              }
            }
          }
        }
      }
  }
}

/// Validates a string value against a specific format
pub fn validate_format(value: String, format: types.StringFormat) -> Bool {
  case format {
    types.DateTime -> is_valid_rfc3339_datetime(value)
    types.Uri -> is_valid_uri(value)
    types.AtUri -> is_valid_at_uri(value)
    types.Did -> is_valid_did(value)
    types.Handle -> is_valid_handle(value)
    types.AtIdentifier -> is_valid_at_identifier(value)
    types.Nsid -> is_valid_nsid(value)
    types.Cid -> is_valid_cid(value)
    types.Language -> is_valid_language_tag(value)
    types.Tid -> is_valid_tid(value)
    types.RecordKey -> is_valid_record_key(value)
  }
}
