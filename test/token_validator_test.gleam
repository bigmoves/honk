import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/meta/token

pub fn main() {
  gleeunit.main()
}

// ========== SCHEMA VALIDATION TESTS ==========

pub fn valid_token_schema_test() {
  let schema = json.object([#("type", json.string("token"))])

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_schema(schema, ctx) |> should.be_ok
}

pub fn valid_token_schema_with_description_test() {
  let schema =
    json.object([
      #("type", json.string("token")),
      #("description", json.string("A token for discrimination")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_schema(schema, ctx) |> should.be_ok
}

pub fn invalid_token_schema_extra_fields_test() {
  let schema =
    json.object([
      #("type", json.string("token")),
      #("extraField", json.string("not allowed")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_schema(schema, ctx) |> should.be_error
}

// ========== DATA VALIDATION TESTS ==========

pub fn valid_token_data_simple_string_test() {
  let schema = json.object([#("type", json.string("token"))])
  let data = json.string("example.lexicon.record#demoToken")

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_data(data, schema, ctx) |> should.be_ok
}

pub fn valid_token_data_local_ref_test() {
  let schema = json.object([#("type", json.string("token"))])
  let data = json.string("#myToken")

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_data(data, schema, ctx) |> should.be_ok
}

pub fn invalid_token_data_empty_string_test() {
  let schema = json.object([#("type", json.string("token"))])
  let data = json.string("")

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_token_data_integer_test() {
  let schema = json.object([#("type", json.string("token"))])
  let data = json.int(123)

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_token_data_boolean_test() {
  let schema = json.object([#("type", json.string("token"))])
  let data = json.bool(True)

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_token_data_object_test() {
  let schema = json.object([#("type", json.string("token"))])
  let data = json.object([#("token", json.string("value"))])

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_token_data_array_test() {
  let schema = json.object([#("type", json.string("token"))])
  let data =
    json.preprocessed_array([json.string("token1"), json.string("token2")])

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_data(data, schema, ctx) |> should.be_error
}

pub fn invalid_token_data_null_test() {
  let schema = json.object([#("type", json.string("token"))])
  let data = json.null()

  let assert Ok(ctx) = context.builder() |> context.build

  token.validate_data(data, schema, ctx) |> should.be_error
}
