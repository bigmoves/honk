// Reusable constraint validation functions

import errors.{type ValidationError}
import gleam/int
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string

/// Validates length constraints (minLength/maxLength)
pub fn validate_length_constraints(
  def_name: String,
  actual_length: Int,
  min_length: Option(Int),
  max_length: Option(Int),
  type_name: String,
) -> Result(Nil, ValidationError) {
  // Check minimum length
  case min_length {
    Some(min) if actual_length < min ->
      Error(errors.data_validation(
        def_name
        <> ": "
        <> type_name
        <> " length "
        <> int.to_string(actual_length)
        <> " is less than minLength "
        <> int.to_string(min),
      ))
    _ -> Ok(Nil)
  }
  |> result.try(fn(_) {
    // Check maximum length
    case max_length {
      Some(max) if actual_length > max ->
        Error(errors.data_validation(
          def_name
          <> ": "
          <> type_name
          <> " length "
          <> int.to_string(actual_length)
          <> " exceeds maxLength "
          <> int.to_string(max),
        ))
      _ -> Ok(Nil)
    }
  })
}

/// Validates min/max length consistency
pub fn validate_length_constraint_consistency(
  def_name: String,
  min_length: Option(Int),
  max_length: Option(Int),
  type_name: String,
) -> Result(Nil, ValidationError) {
  case min_length, max_length {
    Some(min), Some(max) if min > max ->
      Error(errors.invalid_schema(
        def_name
        <> ": "
        <> type_name
        <> " minLength ("
        <> int.to_string(min)
        <> ") cannot be greater than maxLength ("
        <> int.to_string(max)
        <> ")",
      ))
    _, _ -> Ok(Nil)
  }
}

/// Validates integer range constraints
pub fn validate_integer_range(
  def_name: String,
  value: Int,
  minimum: Option(Int),
  maximum: Option(Int),
) -> Result(Nil, ValidationError) {
  // Check minimum
  case minimum {
    Some(min) if value < min ->
      Error(errors.data_validation(
        def_name
        <> ": value "
        <> int.to_string(value)
        <> " is less than minimum "
        <> int.to_string(min),
      ))
    _ -> Ok(Nil)
  }
  |> result.try(fn(_) {
    // Check maximum
    case maximum {
      Some(max) if value > max ->
        Error(errors.data_validation(
          def_name
          <> ": value "
          <> int.to_string(value)
          <> " exceeds maximum "
          <> int.to_string(max),
        ))
      _ -> Ok(Nil)
    }
  })
}

/// Validates integer constraint consistency
pub fn validate_integer_constraint_consistency(
  def_name: String,
  minimum: Option(Int),
  maximum: Option(Int),
) -> Result(Nil, ValidationError) {
  case minimum, maximum {
    Some(min), Some(max) if min > max ->
      Error(errors.invalid_schema(
        def_name
        <> ": minimum ("
        <> int.to_string(min)
        <> ") cannot be greater than maximum ("
        <> int.to_string(max)
        <> ")",
      ))
    _, _ -> Ok(Nil)
  }
}

/// Validates enum constraints
/// The value must be one of the allowed values
/// Note: Gleam doesn't have trait bounds, so we pass a comparison function
pub fn validate_enum_constraint(
  def_name: String,
  value: a,
  enum_values: List(a),
  type_name: String,
  to_string: fn(a) -> String,
  equal: fn(a, a) -> Bool,
) -> Result(Nil, ValidationError) {
  let found = list.any(enum_values, fn(enum_val) { equal(value, enum_val) })

  case found {
    True -> Ok(Nil)
    False ->
      Error(errors.data_validation(
        def_name
        <> ": "
        <> type_name
        <> " value '"
        <> to_string(value)
        <> "' is not in enum",
      ))
  }
}

/// Validates const/default mutual exclusivity
pub fn validate_const_default_exclusivity(
  def_name: String,
  has_const: Bool,
  has_default: Bool,
  type_name: String,
) -> Result(Nil, ValidationError) {
  case has_const, has_default {
    True, True ->
      Error(errors.invalid_schema(
        def_name
        <> ": "
        <> type_name
        <> " cannot have both 'const' and 'default'",
      ))
    _, _ -> Ok(Nil)
  }
}

/// Validates that only allowed fields are present in a schema object
pub fn validate_allowed_fields(
  def_name: String,
  actual_fields: List(String),
  allowed_fields: List(String),
  type_name: String,
) -> Result(Nil, ValidationError) {
  let unknown_fields =
    list.filter(actual_fields, fn(field) {
      !list.contains(allowed_fields, field)
    })

  case unknown_fields {
    [] -> Ok(Nil)
    fields ->
      Error(errors.invalid_schema(
        def_name
        <> ": "
        <> type_name
        <> " has unknown fields: "
        <> string.join(fields, ", ")
        <> ". Allowed fields: "
        <> string.join(allowed_fields, ", "),
      ))
  }
}
