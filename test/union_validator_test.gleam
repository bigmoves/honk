import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/field
import honk/validation/field/union

pub fn main() {
  gleeunit.main()
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

// Test valid union data with $type matching global ref
pub fn valid_union_data_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("com.example.post")], fn(x) { x })),
    ])

  let data =
    json.object([
      #("$type", json.string("com.example.post")),
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
      #("refs", json.array([json.string("com.example.post")], fn(x) { x })),
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
      #("refs", json.array([json.string("com.example.post")], fn(x) { x })),
    ])

  let data = json.string("not an object")

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test closed union rejects $type not in refs
pub fn union_data_type_not_in_refs_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("com.example.typeA")], fn(x) { x })),
      #("closed", json.bool(True)),
    ])

  let data =
    json.object([
      #("$type", json.string("com.example.typeB")),
      #("data", json.string("some data")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test union with invalid ref (non-string in array)
pub fn union_with_invalid_ref_type_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #(
        "refs",
        json.array([json.int(123), json.string("com.example.post")], fn(x) { x }),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_schema(schema, ctx)
  result |> should.be_error
}

// Test local ref matching in data validation
pub fn union_data_local_ref_matching_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #(
        "refs",
        json.array([json.string("#post"), json.string("#reply")], fn(x) { x }),
      ),
    ])

  // Data with $type matching local ref pattern
  let data =
    json.object([
      #("$type", json.string("post")),
      #("text", json.string("Hello")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  // Should pass because local ref #post matches bare name "post"
  result |> should.be_ok
}

// Test local ref with NSID in data
pub fn union_data_local_ref_with_nsid_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("#view")], fn(x) { x })),
    ])

  // Data with $type as full NSID#fragment
  let data =
    json.object([
      #("$type", json.string("com.example.feed#view")),
      #("uri", json.string("at://did:plc:abc/com.example.feed/123")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  // Should pass because local ref #view matches NSID with #view fragment
  result |> should.be_ok
}

// Test multiple local refs in schema
pub fn union_with_multiple_local_refs_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #(
        "refs",
        json.array(
          [json.string("#post"), json.string("#repost"), json.string("#reply")],
          fn(x) { x },
        ),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_schema(schema, ctx)
  // In test context without lexicon catalog, local refs are syntactically valid
  result |> should.be_ok
}

// Test mixed global and local refs
pub fn union_with_mixed_refs_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #(
        "refs",
        json.array(
          [json.string("com.example.post"), json.string("#localDef")],
          fn(x) { x },
        ),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_schema(schema, ctx)
  // In test context without lexicon catalog, both types are syntactically valid
  result |> should.be_ok
}

// Test all primitive types for non-object validation
pub fn union_data_all_non_object_types_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("com.example.post")], fn(x) { x })),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  // Test number
  let number_data = json.int(123)
  union.validate_data(number_data, schema, ctx) |> should.be_error

  // Test string
  let string_data = json.string("not an object")
  union.validate_data(string_data, schema, ctx) |> should.be_error

  // Test null
  let null_data = json.null()
  union.validate_data(null_data, schema, ctx) |> should.be_error

  // Test array
  let array_data = json.array([json.string("item")], fn(x) { x })
  union.validate_data(array_data, schema, ctx) |> should.be_error

  // Test boolean
  let bool_data = json.bool(True)
  union.validate_data(bool_data, schema, ctx) |> should.be_error
}

// Test empty refs in data validation context
pub fn union_data_empty_refs_test() {
  let schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([], fn(x) { x })),
    ])

  let data =
    json.object([
      #("$type", json.string("any.type")),
      #("data", json.string("some data")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = union.validate_data(data, schema, ctx)
  // Data validation should fail with empty refs array
  result |> should.be_error
}

// Test comprehensive reference matching with full lexicon catalog
pub fn union_data_reference_matching_test() {
  // Set up lexicons with local, global main, and fragment refs
  let main_lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.test")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("union")),
              #(
                "refs",
                json.array(
                  [
                    json.string("#localType"),
                    json.string("com.example.global#main"),
                    json.string("com.example.types#fragmentType"),
                  ],
                  fn(x) { x },
                ),
              ),
            ]),
          ),
          #(
            "localType",
            json.object([
              #("type", json.string("object")),
              #("properties", json.object([])),
            ]),
          ),
        ]),
      ),
    ])

  let global_lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.global")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("object")),
              #("properties", json.object([])),
            ]),
          ),
        ]),
      ),
    ])

  let types_lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.types")),
      #(
        "defs",
        json.object([
          #(
            "fragmentType",
            json.object([
              #("type", json.string("object")),
              #("properties", json.object([])),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([main_lexicon, global_lexicon, types_lexicon])

  let assert Ok(ctx) = builder |> context.build()
  let ctx = context.with_current_lexicon(ctx, "com.example.test")

  let schema =
    json.object([
      #("type", json.string("union")),
      #(
        "refs",
        json.array(
          [
            json.string("#localType"),
            json.string("com.example.global#main"),
            json.string("com.example.types#fragmentType"),
          ],
          fn(x) { x },
        ),
      ),
    ])

  // Test local reference match
  let local_data = json.object([#("$type", json.string("localType"))])
  union.validate_data(local_data, schema, ctx) |> should.be_ok

  // Test global main reference match
  let global_data =
    json.object([#("$type", json.string("com.example.global#main"))])
  union.validate_data(global_data, schema, ctx) |> should.be_ok

  // Test global fragment reference match
  let fragment_data =
    json.object([#("$type", json.string("com.example.types#fragmentType"))])
  union.validate_data(fragment_data, schema, ctx) |> should.be_ok
}

// Test full schema resolution with constraint validation
pub fn union_data_with_schema_resolution_test() {
  let main_lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.feed")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("union")),
              #(
                "refs",
                json.array(
                  [
                    json.string("#post"),
                    json.string("#repost"),
                    json.string("com.example.types#like"),
                  ],
                  fn(x) { x },
                ),
              ),
            ]),
          ),
          #(
            "post",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #(
                    "title",
                    json.object([
                      #("type", json.string("string")),
                      #("maxLength", json.int(100)),
                    ]),
                  ),
                  #("content", json.object([#("type", json.string("string"))])),
                ]),
              ),
              #("required", json.array([json.string("title")], fn(x) { x })),
            ]),
          ),
          #(
            "repost",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #("original", json.object([#("type", json.string("string"))])),
                  #("comment", json.object([#("type", json.string("string"))])),
                ]),
              ),
              #("required", json.array([json.string("original")], fn(x) { x })),
            ]),
          ),
        ]),
      ),
    ])

  let types_lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.types")),
      #(
        "defs",
        json.object([
          #(
            "like",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #("target", json.object([#("type", json.string("string"))])),
                  #(
                    "emoji",
                    json.object([
                      #("type", json.string("string")),
                      #("maxLength", json.int(10)),
                    ]),
                  ),
                ]),
              ),
              #("required", json.array([json.string("target")], fn(x) { x })),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([main_lexicon, types_lexicon])

  let assert Ok(ctx) = builder |> context.build()
  let ctx = context.with_current_lexicon(ctx, "com.example.feed")

  let union_schema =
    json.object([
      #("type", json.string("union")),
      #(
        "refs",
        json.array(
          [
            json.string("#post"),
            json.string("#repost"),
            json.string("com.example.types#like"),
          ],
          fn(x) { x },
        ),
      ),
    ])

  // Test valid post data (with all required fields)
  let valid_post =
    json.object([
      #("$type", json.string("post")),
      #("title", json.string("My Post")),
      #("content", json.string("This is my post content")),
    ])
  union.validate_data(valid_post, union_schema, ctx) |> should.be_ok

  // Test invalid post data (missing required field)
  let invalid_post =
    json.object([
      #("$type", json.string("post")),
      #("content", json.string("This is missing a title")),
    ])
  union.validate_data(invalid_post, union_schema, ctx) |> should.be_error

  // Test valid repost data (with all required fields)
  let valid_repost =
    json.object([
      #("$type", json.string("repost")),
      #("original", json.string("original-post-uri")),
      #("comment", json.string("Great post!")),
    ])
  union.validate_data(valid_repost, union_schema, ctx) |> should.be_ok

  // Test valid like data (global reference with all required fields)
  let valid_like =
    json.object([
      #("$type", json.string("com.example.types#like")),
      #("target", json.string("post-uri")),
      #("emoji", json.string("👍")),
    ])
  union.validate_data(valid_like, union_schema, ctx) |> should.be_ok

  // Test invalid like data (missing required field)
  let invalid_like =
    json.object([
      #("$type", json.string("com.example.types#like")),
      #("emoji", json.string("👍")),
    ])
  union.validate_data(invalid_like, union_schema, ctx) |> should.be_error
}

// Test open vs closed union comparison
pub fn union_data_open_vs_closed_test() {
  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.test")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("union")),
              #("refs", json.array([json.string("#post")], fn(x) { x })),
              #("closed", json.bool(False)),
            ]),
          ),
          #(
            "post",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #("title", json.object([#("type", json.string("string"))])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([lexicon])
  let assert Ok(ctx) = builder |> context.build()
  let ctx = context.with_current_lexicon(ctx, "com.example.test")

  let open_union_schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("#post")], fn(x) { x })),
      #("closed", json.bool(False)),
    ])

  let closed_union_schema =
    json.object([
      #("type", json.string("union")),
      #("refs", json.array([json.string("#post")], fn(x) { x })),
      #("closed", json.bool(True)),
    ])

  // Known $type should work in both
  let known_type =
    json.object([
      #("$type", json.string("post")),
      #("title", json.string("Test")),
    ])
  union.validate_data(known_type, open_union_schema, ctx) |> should.be_ok
  union.validate_data(known_type, closed_union_schema, ctx) |> should.be_ok

  // Unknown $type - behavior differs between open/closed
  let unknown_type =
    json.object([
      #("$type", json.string("unknown_type")),
      #("data", json.string("test")),
    ])
  // Open union should accept unknown types
  union.validate_data(unknown_type, open_union_schema, ctx) |> should.be_ok
  // Closed union should reject unknown types
  union.validate_data(unknown_type, closed_union_schema, ctx) |> should.be_error
}

// Test basic union with full lexicon context
pub fn union_data_basic_with_full_context_test() {
  let main_lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.test")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("union")),
              #(
                "refs",
                json.array(
                  [
                    json.string("#post"),
                    json.string("#repost"),
                    json.string("com.example.like#main"),
                  ],
                  fn(x) { x },
                ),
              ),
            ]),
          ),
          #(
            "post",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #("title", json.object([#("type", json.string("string"))])),
                  #("content", json.object([#("type", json.string("string"))])),
                ]),
              ),
            ]),
          ),
          #(
            "repost",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #("original", json.object([#("type", json.string("string"))])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let like_lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("com.example.like")),
      #(
        "defs",
        json.object([
          #(
            "main",
            json.object([
              #("type", json.string("object")),
              #(
                "properties",
                json.object([
                  #("target", json.object([#("type", json.string("string"))])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([main_lexicon, like_lexicon])

  let assert Ok(ctx) = builder |> context.build()
  let ctx = context.with_current_lexicon(ctx, "com.example.test")

  let schema =
    json.object([
      #("type", json.string("union")),
      #(
        "refs",
        json.array(
          [
            json.string("#post"),
            json.string("#repost"),
            json.string("com.example.like#main"),
          ],
          fn(x) { x },
        ),
      ),
    ])

  // Valid union data with local reference
  let post_data =
    json.object([
      #("$type", json.string("post")),
      #("title", json.string("My Post")),
      #("content", json.string("Post content")),
    ])
  union.validate_data(post_data, schema, ctx) |> should.be_ok

  // Valid union data with global reference
  let like_data =
    json.object([
      #("$type", json.string("com.example.like#main")),
      #("target", json.string("some-target")),
    ])
  union.validate_data(like_data, schema, ctx) |> should.be_ok
}
