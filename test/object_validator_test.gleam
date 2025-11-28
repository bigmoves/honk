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

// Test nullable field accepts null value
pub fn nullable_field_accepts_null_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #(
        "properties",
        json.object([
          #("name", json.object([#("type", json.string("string"))])),
          #("duration", json.object([#("type", json.string("integer"))])),
        ]),
      ),
      #("nullable", json.array([json.string("duration")], fn(x) { x })),
    ])

  let data =
    json.object([
      #("name", json.string("test")),
      #("duration", json.null()),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_object_data(data, schema, ctx)
  result |> should.be_ok
}

// Test non-nullable field rejects null value
pub fn non_nullable_field_rejects_null_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #(
        "properties",
        json.object([
          #("name", json.object([#("type", json.string("string"))])),
          #("count", json.object([#("type", json.string("integer"))])),
        ]),
      ),
      // No nullable array - count cannot be null
    ])

  let data =
    json.object([
      #("name", json.string("test")),
      #("count", json.null()),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_object_data(data, schema, ctx)
  result |> should.be_error
}

// Test nullable field must exist in properties (schema validation)
pub fn nullable_field_not_in_properties_fails_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #(
        "properties",
        json.object([
          #("name", json.object([#("type", json.string("string"))])),
        ]),
      ),
      // "nonexistent" is not in properties
      #("nullable", json.array([json.string("nonexistent")], fn(x) { x })),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_object_schema(schema, ctx)
  result |> should.be_error
}

// Test valid nullable schema passes validation
pub fn valid_nullable_schema_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #(
        "properties",
        json.object([
          #("name", json.object([#("type", json.string("string"))])),
          #("duration", json.object([#("type", json.string("integer"))])),
        ]),
      ),
      #("nullable", json.array([json.string("duration")], fn(x) { x })),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_object_schema(schema, ctx)
  result |> should.be_ok
}
