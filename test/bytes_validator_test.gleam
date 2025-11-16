import gleam/json
import gleeunit
import gleeunit/should
import validation/context
import validation/primitive/bytes

pub fn main() {
  gleeunit.main()
}

// ========== SCHEMA VALIDATION TESTS ==========

pub fn valid_bytes_schema_basic_test() {
  let schema = json.object([#("type", json.string("bytes"))])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_schema(schema, ctx) |> should.be_ok
}

pub fn valid_bytes_schema_with_min_max_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("minLength", json.int(10)),
      #("maxLength", json.int(20)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_schema(schema, ctx) |> should.be_ok
}

pub fn valid_bytes_schema_with_description_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("description", json.string("Binary data")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_schema(schema, ctx) |> should.be_ok
}

pub fn invalid_bytes_schema_extra_fields_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("extraField", json.string("not allowed")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_schema(schema, ctx) |> should.be_error
}

pub fn invalid_bytes_schema_max_less_than_min_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("minLength", json.int(20)),
      #("maxLength", json.int(10)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_schema(schema, ctx) |> should.be_error
}

pub fn invalid_bytes_schema_negative_min_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("minLength", json.int(-1)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_schema(schema, ctx) |> should.be_error
}

pub fn invalid_bytes_schema_negative_max_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("maxLength", json.int(-5)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_schema(schema, ctx) |> should.be_error
}

// ========== DATA VALIDATION TESTS ==========

pub fn valid_bytes_data_basic_test() {
  let schema = json.object([#("type", json.string("bytes"))])
  // "123" in base64 is "MTIz"
  let data = json.object([#("$bytes", json.string("MTIz"))])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_ok
}

pub fn valid_bytes_data_with_length_constraints_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("minLength", json.int(10)),
      #("maxLength", json.int(20)),
    ])
  // Base64 string that decodes to exactly 16 bytes
  let data = json.object([#("$bytes", json.string("YXNkZmFzZGZhc2RmYXNkZg"))])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_ok
}

pub fn invalid_bytes_data_plain_string_test() {
  let schema = json.object([#("type", json.string("bytes"))])
  // Plain string instead of object with $bytes
  let data = json.string("green")

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_bytes_data_empty_object_test() {
  let schema = json.object([#("type", json.string("bytes"))])
  // Empty object
  let data = json.object([])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_bytes_data_wrong_field_name_test() {
  let schema = json.object([#("type", json.string("bytes"))])
  // Wrong field name - should be "$bytes" not "bytes"
  let data = json.object([#("bytes", json.string("YXNkZmFzZGZhc2RmYXNkZg"))])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_bytes_data_extra_fields_test() {
  let schema = json.object([#("type", json.string("bytes"))])
  // Object with extra fields - must have exactly one field
  let data =
    json.object([
      #("$bytes", json.string("MTIz")),
      #("other", json.string("blah")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_bytes_data_non_string_value_test() {
  let schema = json.object([#("type", json.string("bytes"))])
  // $bytes value is not a string
  let data =
    json.object([
      #("$bytes", json.preprocessed_array([json.int(1), json.int(2)])),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_bytes_data_invalid_base64_test() {
  let schema = json.object([#("type", json.string("bytes"))])
  // Invalid base64 string (contains invalid characters)
  let data = json.object([#("$bytes", json.string("not!valid@base64"))])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_bytes_data_too_short_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("minLength", json.int(10)),
    ])
  // "b25l" decodes to "one" which is only 3 bytes
  let data = json.object([#("$bytes", json.string("b25l"))])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_bytes_data_too_long_test() {
  let schema =
    json.object([
      #("type", json.string("bytes")),
      #("maxLength", json.int(5)),
    ])
  // "YXNkZmFzZGZhc2RmYXNkZg" decodes to "asdfasdfasdfasdf" which is 16 bytes
  let data = json.object([#("$bytes", json.string("YXNkZmFzZGZhc2RmYXNkZg"))])

  let assert Ok(ctx) = context.builder() |> context.build

  bytes.validate_data(data, schema, ctx) |> should.be_error
}
