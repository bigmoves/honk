// Error types for lexicon validation

pub type ValidationError {
  LexiconNotFound(collection: String)
  InvalidSchema(message: String)
  DataValidation(message: String)
}

/// Convert error to human-readable string
pub fn to_string(error: ValidationError) -> String {
  case error {
    LexiconNotFound(collection) ->
      "Lexicon not found for collection: " <> collection
    InvalidSchema(message) -> "Invalid lexicon schema: " <> message
    DataValidation(message) -> "Data validation failed: " <> message
  }
}

/// Create an InvalidSchema error with context
pub fn invalid_schema(message: String) -> ValidationError {
  InvalidSchema(message)
}

/// Create a DataValidation error with context
pub fn data_validation(message: String) -> ValidationError {
  DataValidation(message)
}

/// Create a LexiconNotFound error
pub fn lexicon_not_found(collection: String) -> ValidationError {
  LexiconNotFound(collection)
}
