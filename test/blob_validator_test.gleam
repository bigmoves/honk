import gleam/json
import gleeunit
import gleeunit/should
import validation/context
import validation/primitive/blob

pub fn main() {
  gleeunit.main()
}

// Test valid blob schema
pub fn valid_blob_schema_test() {
  let schema =
    json.object([
      #("type", json.string("blob")),
      #(
        "accept",
        json.array([json.string("image/*"), json.string("video/mp4")], fn(x) {
          x
        }),
      ),
      #("maxSize", json.int(1_048_576)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test blob with wildcard MIME type
pub fn wildcard_mime_type_test() {
  let schema =
    json.object([
      #("type", json.string("blob")),
      #("accept", json.array([json.string("*/*")], fn(x) { x })),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test invalid MIME type pattern (missing slash)
pub fn invalid_mime_type_no_slash_test() {
  let schema =
    json.object([
      #("type", json.string("blob")),
      #("accept", json.array([json.string("image")], fn(x) { x })),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test invalid MIME type pattern (partial wildcard)
pub fn invalid_mime_type_partial_wildcard_test() {
  let schema =
    json.object([
      #("type", json.string("blob")),
      #("accept", json.array([json.string("image/jpe*")], fn(x) { x })),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test zero maxSize
pub fn zero_max_size_test() {
  let schema =
    json.object([
      #("type", json.string("blob")),
      #("maxSize", json.int(0)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test valid blob data
pub fn valid_blob_data_test() {
  let schema =
    json.object([
      #("type", json.string("blob")),
      #("accept", json.array([json.string("image/*")], fn(x) { x })),
      #("maxSize", json.int(1_000_000)),
    ])

  let data =
    json.object([
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test blob data with unaccepted MIME type
pub fn unaccepted_mime_type_test() {
  let schema =
    json.object([
      #("type", json.string("blob")),
      #("accept", json.array([json.string("image/*")], fn(x) { x })),
    ])

  let data =
    json.object([
      #("mimeType", json.string("video/mp4")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test blob data exceeding maxSize
pub fn exceeds_max_size_test() {
  let schema =
    json.object([
      #("type", json.string("blob")),
      #("maxSize", json.int(10_000)),
    ])

  let data =
    json.object([
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test blob data missing mimeType
pub fn missing_mime_type_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data = json.object([#("size", json.int(50_000))])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test blob data missing size
pub fn missing_size_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data = json.object([#("mimeType", json.string("image/jpeg"))])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}
