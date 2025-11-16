// Core types for AT Protocol lexicon validation

import gleam/json.{type Json}

/// Represents a parsed lexicon document
pub type LexiconDoc {
  LexiconDoc(id: String, defs: Json)
}

/// AT Protocol string formats
pub type StringFormat {
  DateTime
  Uri
  AtUri
  Did
  Handle
  AtIdentifier
  Nsid
  Cid
  Language
  Tid
  RecordKey
}

/// Convert a string to a StringFormat
pub fn string_to_format(s: String) -> Result(StringFormat, Nil) {
  case s {
    "datetime" -> Ok(DateTime)
    "uri" -> Ok(Uri)
    "at-uri" -> Ok(AtUri)
    "did" -> Ok(Did)
    "handle" -> Ok(Handle)
    "at-identifier" -> Ok(AtIdentifier)
    "nsid" -> Ok(Nsid)
    "cid" -> Ok(Cid)
    "language" -> Ok(Language)
    "tid" -> Ok(Tid)
    "record-key" -> Ok(RecordKey)
    _ -> Error(Nil)
  }
}

/// Convert a StringFormat to string
pub fn format_to_string(format: StringFormat) -> String {
  case format {
    DateTime -> "datetime"
    Uri -> "uri"
    AtUri -> "at-uri"
    Did -> "did"
    Handle -> "handle"
    AtIdentifier -> "at-identifier"
    Nsid -> "nsid"
    Cid -> "cid"
    Language -> "language"
    Tid -> "tid"
    RecordKey -> "record-key"
  }
}
