import gleam/json
import gleeunit
import gleeunit/should
import validation/context
import validation/field

pub fn main() {
  gleeunit.main()
}

// Test valid array schema with string items
pub fn valid_string_array_schema_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #("items", json.object([#("type", json.string("string"))])),
      #("minLength", json.int(1)),
      #("maxLength", json.int(10)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_schema(schema, ctx)
  result |> should.be_ok
}

// Test array schema with object items
pub fn array_with_object_items_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #(
        "items",
        json.object([
          #("type", json.string("object")),
          #(
            "properties",
            json.object([
              #("name", json.object([#("type", json.string("string"))])),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_schema(schema, ctx)
  result |> should.be_ok
}

// Test array schema with nested array items
pub fn nested_array_schema_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #(
        "items",
        json.object([
          #("type", json.string("array")),
          #("items", json.object([#("type", json.string("integer"))])),
        ]),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_schema(schema, ctx)
  result |> should.be_ok
}

// Test array schema missing items field
pub fn missing_items_field_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #("maxLength", json.int(10)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_schema(schema, ctx)
  result |> should.be_error
}

// Test array schema with invalid length constraints
pub fn invalid_length_constraints_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #("items", json.object([#("type", json.string("string"))])),
      #("minLength", json.int(10)),
      #("maxLength", json.int(5)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_schema(schema, ctx)
  result |> should.be_error
}

// Test valid array data
pub fn valid_array_data_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #("items", json.object([#("type", json.string("string"))])),
      #("minLength", json.int(1)),
      #("maxLength", json.int(5)),
    ])

  let data =
    json.array([json.string("hello"), json.string("world")], fn(x) { x })

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_data(data, schema, ctx)
  result |> should.be_ok
}

// Test array data below minLength
pub fn array_below_min_length_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #("items", json.object([#("type", json.string("string"))])),
      #("minLength", json.int(3)),
    ])

  let data = json.array([json.string("hello")], fn(x) { x })

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_data(data, schema, ctx)
  result |> should.be_error
}

// Test array data above maxLength
pub fn array_above_max_length_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #("items", json.object([#("type", json.string("string"))])),
      #("maxLength", json.int(2)),
    ])

  let data =
    json.array([json.string("a"), json.string("b"), json.string("c")], fn(x) {
      x
    })

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_data(data, schema, ctx)
  result |> should.be_error
}

// Test array data with invalid item type
pub fn invalid_item_type_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #("items", json.object([#("type", json.string("string"))])),
    ])

  let data = json.array([json.string("hello"), json.int(42)], fn(x) { x })

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_data(data, schema, ctx)
  result |> should.be_error
}

// Test empty array with minLength
pub fn empty_array_with_min_length_test() {
  let schema =
    json.object([
      #("type", json.string("array")),
      #("items", json.object([#("type", json.string("string"))])),
      #("minLength", json.int(1)),
    ])

  let data = json.array([], fn(x) { x })

  let assert Ok(ctx) = context.builder() |> context.build
  let result = field.validate_array_data(data, schema, ctx)
  result |> should.be_error
}
