import gleam/json
import gleeunit
import gleeunit/should
import honk/errors
import honk/validation/context
import honk/validation/field

pub fn main() {
  gleeunit.main()
}

// Test valid object schema
pub fn valid_object_schema_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #(
        "properties",
        json.object([
          #("title", json.object([#("type", json.string("string"))])),
          #("count", json.object([#("type", json.string("integer"))])),
        ]),
      ),
      #("required", json.array([json.string("title")], fn(x) { x })),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_object_schema(schema, ctx)
  result |> should.be_ok
}

// Test valid object data
pub fn valid_object_data_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #(
        "properties",
        json.object([
          #("title", json.object([#("type", json.string("string"))])),
          #("count", json.object([#("type", json.string("integer"))])),
        ]),
      ),
      #("required", json.array([json.string("title")], fn(x) { x })),
    ])

  let data =
    json.object([
      #("title", json.string("Hello")),
      #("count", json.int(42)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_object_data(data, schema, ctx)
  result |> should.be_ok
}

// Test missing required field
pub fn missing_required_field_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #(
        "properties",
        json.object([
          #("title", json.object([#("type", json.string("string"))])),
        ]),
      ),
      #("required", json.array([json.string("title")], fn(x) { x })),
    ])

  let data = json.object([#("other", json.string("value"))])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_object_data(data, schema, ctx)
  result |> should.be_error
}

// Test missing required field error message at root level (no path)
pub fn missing_required_field_message_root_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #(
        "properties",
        json.object([
          #("title", json.object([#("type", json.string("string"))])),
        ]),
      ),
      #("required", json.array([json.string("title")], fn(x) { x })),
    ])

  let data = json.object([#("other", json.string("value"))])

  let assert Ok(ctx) = context.builder() |> context.build
  let assert Error(error) = field.validate_object_data(data, schema, ctx)

  let error_message = errors.to_string(error)
  error_message
  |> should.equal("Data validation failed: required field 'title' is missing")
}
