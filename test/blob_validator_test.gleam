import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/primitive/blob

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
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
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
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
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
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
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

  let data =
    json.object([
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test blob data missing size
pub fn missing_size_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("image/jpeg")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// ========== FULL BLOB STRUCTURE TESTS ==========

// Test valid full blob structure
pub fn valid_full_blob_structure_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test missing $type field
pub fn missing_type_field_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test wrong $type value
pub fn wrong_type_value_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("notblob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test missing ref field
pub fn missing_ref_field_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test ref without $link
pub fn ref_missing_link_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #("ref", json.object([#("cid", json.string("bafkrei..."))])),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test ref with invalid CID
pub fn ref_invalid_cid_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #("ref", json.object([#("$link", json.string("not-a-valid-cid"))])),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test ref with dag-cbor CID (should fail - blobs need raw multicodec)
pub fn ref_dag_cbor_cid_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test empty mimeType rejected
pub fn empty_mime_type_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("")),
      #("size", json.int(50_000)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test size zero is allowed (per atproto implementation)
pub fn size_zero_allowed_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(0)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test negative size rejected
pub fn negative_size_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(-100)),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test extra fields are rejected (strict mode per atproto implementation)
pub fn extra_fields_rejected_test() {
  let schema = json.object([#("type", json.string("blob"))])

  let data =
    json.object([
      #("$type", json.string("blob")),
      #(
        "ref",
        json.object([
          #(
            "$link",
            json.string(
              "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
            ),
          ),
        ]),
      ),
      #("mimeType", json.string("image/jpeg")),
      #("size", json.int(50_000)),
      #("extraField", json.string("not allowed")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = blob.validate_data(data, schema, ctx)
  result |> should.be_error
}
