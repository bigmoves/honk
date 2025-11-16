import gleam/json
import gleeunit
import gleeunit/should
import validation/context
import validation/meta/unknown

pub fn main() {
  gleeunit.main()
}

// ========== SCHEMA VALIDATION TESTS ==========

pub fn valid_unknown_schema_test() {
  let schema = json.object([#("type", json.string("unknown"))])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_schema(schema, ctx) |> should.be_ok
}

pub fn valid_unknown_schema_with_description_test() {
  let schema =
    json.object([
      #("type", json.string("unknown")),
      #("description", json.string("Flexible data following ATProto rules")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_schema(schema, ctx) |> should.be_ok
}

pub fn invalid_unknown_schema_extra_fields_test() {
  let schema =
    json.object([
      #("type", json.string("unknown")),
      #("extraField", json.string("not allowed")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_schema(schema, ctx) |> should.be_error
}

// ========== DATA VALIDATION TESTS ==========

pub fn valid_unknown_data_simple_object_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data = json.object([#("a", json.string("alphabet")), #("b", json.int(3))])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_ok
}

pub fn valid_unknown_data_with_type_field_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data =
    json.object([
      #("$type", json.string("example.lexicon.record#demoObject")),
      #("a", json.int(1)),
      #("b", json.int(2)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_ok
}

pub fn valid_unknown_data_nested_objects_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data =
    json.object([
      #("outer", json.object([#("inner", json.string("nested"))])),
      #("count", json.int(42)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_ok
}

pub fn valid_unknown_data_empty_object_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data = json.object([])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_ok
}

pub fn invalid_unknown_data_boolean_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data = json.bool(False)

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_unknown_data_string_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data = json.string("not an object")

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_unknown_data_integer_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data = json.int(123)

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_unknown_data_array_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data = json.preprocessed_array([json.int(1), json.int(2), json.int(3)])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_unknown_data_null_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  let data = json.null()

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_unknown_data_bytes_object_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  // Bytes object: {"$bytes": "base64-string"}
  let data = json.object([#("$bytes", json.string("SGVsbG8gd29ybGQ="))])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_unknown_data_blob_object_test() {
  let schema = json.object([#("type", json.string("unknown"))])
  // Blob object: {"$type": "blob", ...}
  let data =
    json.object([
      #("$type", json.string("blob")),
      #("mimeType", json.string("text/plain")),
      #("size", json.int(12_345)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  unknown.validate_data(data, schema, ctx) |> should.be_error
}
