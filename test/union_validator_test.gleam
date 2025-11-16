import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/field/union

pub fn main() {
  gleeunit.main()
}

// Test valid union schema with refs
pub fn valid_union_schema_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #(
        "refs",
        json.array([json.string("#post"), json.string("#repost")], fn(x) { x }),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test union schema with closed flag
pub fn closed_union_schema_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("#post")], fn(x) { x })),
      #("closed", json.bool(True)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test open union with empty refs
pub fn open_union_empty_refs_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([], fn(x) { x })),
      #("closed", json.bool(False)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test closed union with empty refs (should fail)
pub fn closed_union_empty_refs_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([], fn(x) { x })),
      #("closed", json.bool(True)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test union missing refs field
pub fn union_missing_refs_test() {
  let schema = json.object([#("type", json.string("union"))])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test valid union data with $type
pub fn valid_union_data_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("app.bsky.feed.post")], fn(x) { x })),
    ])

  let data =
    json.object([
      #("$type", json.string("app.bsky.feed.post")),
      #("text", json.string("Hello world")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test union data missing $type field
pub fn union_data_missing_type_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("#post")], fn(x) { x })),
    ])

  let data = json.object([#("text", json.string("Hello"))])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test union data with non-object value
pub fn union_data_non_object_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("#post")], fn(x) { x })),
    ])

  let data = json.string("not an object")

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test union data with $type not in refs
pub fn union_data_type_not_in_refs_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("app.bsky.feed.post")], fn(x) { x })),
      #("closed", json.bool(True)),
    ])

  let data =
    json.object([
      #("$type", json.string("app.bsky.feed.repost")),
      #("text", json.string("Hello")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  result |> should.be_error
}
