import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/primitive/string

pub fn main() {
  gleeunit.main()
}

// Test valid string schema
pub fn valid_string_schema_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("minLength", json.int(1)),
      #("maxLength", json.int(100)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test string schema with format
pub fn string_with_format_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("format", json.string("uri")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test string schema with enum
pub fn string_with_enum_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #(
        "enum",
        json.array(
          [json.string("red"), json.string("green"), json.string("blue")],
          fn(x) { x },
        ),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test invalid string schema (minLength > maxLength)
pub fn invalid_length_constraints_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("minLength", json.int(100)),
      #("maxLength", json.int(10)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test valid string data
pub fn valid_string_data_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("minLength", json.int(1)),
      #("maxLength", json.int(10)),
    ])

  let data = json.string("hello")

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test string data below minLength
pub fn string_below_min_length_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("minLength", json.int(10)),
    ])

  let data = json.string("short")

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test string data above maxLength
pub fn string_above_max_length_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("maxLength", json.int(5)),
    ])

  let data = json.string("this is too long")

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test string data with enum validation
pub fn string_enum_valid_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #(
        "enum",
        json.array([json.string("red"), json.string("blue")], fn(x) { x }),
      ),
    ])

  let data = json.string("red")

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test string data with enum validation (invalid value)
pub fn string_enum_invalid_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #(
        "enum",
        json.array([json.string("red"), json.string("blue")], fn(x) { x }),
      ),
    ])

  let data = json.string("green")

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test wrong type (number instead of string)
pub fn wrong_type_test() {
  let schema = json.object([#("type", json.string("string"))])

  let data = json.int(42)

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_data(data, schema, ctx)
  result |> should.be_error
}

// ========== NEGATIVE VALUE SCHEMA VALIDATION TESTS ==========

// Test invalid string schema with negative minLength
pub fn invalid_negative_min_length_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("minLength", json.int(-1)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test invalid string schema with negative maxLength
pub fn invalid_negative_max_length_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("maxLength", json.int(-5)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test invalid string schema with negative minGraphemes
pub fn invalid_negative_min_graphemes_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("minGraphemes", json.int(-10)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test invalid string schema with negative maxGraphemes
pub fn invalid_negative_max_graphemes_test() {
  let schema =
    json.object([
      #("type", json.string("string")),
      #("maxGraphemes", json.int(-3)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = string.validate_schema(schema, ctx)
  result |> should.be_error
}
