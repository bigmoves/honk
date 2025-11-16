import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/primitive/integer

pub fn main() {
  gleeunit.main()
}

// Test valid integer schema
pub fn valid_integer_schema_test() {
  let schema =
    json.object([
      #("type", json.string("integer")),
      #("minimum", json.int(0)),
      #("maximum", json.int(100)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test integer schema with enum
pub fn integer_with_enum_test() {
  let schema =
    json.object([
      #("type", json.string("integer")),
      #(
        "enum",
        json.array([json.int(1), json.int(2), json.int(3)], fn(x) { x }),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test invalid integer schema (min > max)
pub fn invalid_range_constraints_test() {
  let schema =
    json.object([
      #("type", json.string("integer")),
      #("minimum", json.int(100)),
      #("maximum", json.int(10)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test valid integer data
pub fn valid_integer_data_test() {
  let schema =
    json.object([
      #("type", json.string("integer")),
      #("minimum", json.int(0)),
      #("maximum", json.int(100)),
    ])

  let data = json.int(42)

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test integer below minimum
pub fn integer_below_minimum_test() {
  let schema =
    json.object([
      #("type", json.string("integer")),
      #("minimum", json.int(10)),
    ])

  let data = json.int(5)

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test integer above maximum
pub fn integer_above_maximum_test() {
  let schema =
    json.object([
      #("type", json.string("integer")),
      #("maximum", json.int(10)),
    ])

  let data = json.int(15)

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test integer enum validation (valid)
pub fn integer_enum_valid_test() {
  let schema =
    json.object([
      #("type", json.string("integer")),
      #(
        "enum",
        json.array([json.int(1), json.int(2), json.int(3)], fn(x) { x }),
      ),
    ])

  let data = json.int(2)

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test integer enum validation (invalid)
pub fn integer_enum_invalid_test() {
  let schema =
    json.object([
      #("type", json.string("integer")),
      #(
        "enum",
        json.array([json.int(1), json.int(2), json.int(3)], fn(x) { x }),
      ),
    ])

  let data = json.int(5)

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test wrong type (string instead of integer)
pub fn wrong_type_test() {
  let schema = json.object([#("type", json.string("integer"))])

  let data = json.string("42")

  let assert Ok(ctx) = context.builder() |> context.build
  let result = integer.validate_data(data, schema, ctx)
  result |> should.be_error
}
