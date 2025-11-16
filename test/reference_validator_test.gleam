import gleam/json
import gleeunit
import gleeunit/should
import validation/context
import validation/field
import validation/field/reference

pub fn main() {
  gleeunit.main()
}

// ========== SCHEMA VALIDATION TESTS ==========

pub fn valid_local_reference_schema_test() {
  let schema =
    json.object([#("type", json.string("ref")), #("ref", json.string("#post"))])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_ok
}

pub fn valid_global_reference_schema_test() {
  let schema =
    json.object([
      #("type", json.string("ref")),
      #("ref", json.string("com.atproto.repo.strongRef#main")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_ok
}

pub fn valid_global_main_reference_schema_test() {
  let schema =
    json.object([
      #("type", json.string("ref")),
      #("ref", json.string("com.atproto.repo.strongRef")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_ok
}

pub fn invalid_empty_ref_test() {
  let schema =
    json.object([#("type", json.string("ref")), #("ref", json.string(""))])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_error
}

pub fn invalid_missing_ref_field_test() {
  let schema = json.object([#("type", json.string("ref"))])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_error
}

pub fn invalid_local_ref_no_def_name_test() {
  let schema =
    json.object([#("type", json.string("ref")), #("ref", json.string("#"))])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_error
}

pub fn invalid_global_ref_empty_nsid_test() {
  // Test that a global reference must have an NSID before the #
  // The reference "com.example#main" is valid, but starting with just # makes it local
  // This test actually verifies that "#" alone (empty def name) is invalid
  let schema =
    json.object([#("type", json.string("ref")), #("ref", json.string("#"))])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_error
}

pub fn invalid_global_ref_empty_def_test() {
  let schema =
    json.object([
      #("type", json.string("ref")),
      #("ref", json.string("com.example.lexicon#")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_error
}

pub fn invalid_multiple_hash_test() {
  let schema =
    json.object([
      #("type", json.string("ref")),
      #("ref", json.string("com.example#foo#bar")),
    ])

  let assert Ok(ctx) = context.builder() |> context.build

  reference.validate_schema(schema, ctx) |> should.be_error
}

// ========== DATA VALIDATION TESTS ==========

pub fn valid_reference_to_string_test() {
  // Create a simple lexicon with a string definition
  let defs =
    json.object([
      #(
        "post",
        json.object([
          #("type", json.string("string")),
          #("maxLength", json.int(280)),
        ]),
      ),
    ])

  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.bsky.feed.post")),
      #("defs", defs),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([lexicon])

  let assert Ok(ctx) = context.build(builder)
  let ctx = context.with_current_lexicon(ctx, "app.bsky.feed.post")

  let ref_schema =
    json.object([#("type", json.string("ref")), #("ref", json.string("#post"))])

  let data = json.string("Hello, world!")

  reference.validate_data(data, ref_schema, ctx)
  |> should.be_ok
}

pub fn valid_reference_to_object_test() {
  // Create a lexicon with an object definition
  let defs =
    json.object([
      #(
        "user",
        json.object([
          #("type", json.string("object")),
          #(
            "properties",
            json.object([
              #(
                "name",
                json.object([
                  #("type", json.string("string")),
                  #("required", json.bool(True)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.test.schema")),
      #("defs", defs),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([lexicon])

  let assert Ok(ctx) = context.build(builder)
  let ctx = context.with_current_lexicon(ctx, "app.test.schema")

  let ref_schema =
    json.object([#("type", json.string("ref")), #("ref", json.string("#user"))])

  let data = json.object([#("name", json.string("Alice"))])

  reference.validate_data(data, ref_schema, ctx)
  |> should.be_ok
}

pub fn invalid_reference_not_found_test() {
  let defs = json.object([])

  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.test.schema")),
      #("defs", defs),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([lexicon])

  let assert Ok(ctx) = context.build(builder)
  let ctx = context.with_current_lexicon(ctx, "app.test.schema")

  let ref_schema =
    json.object([
      #("type", json.string("ref")),
      #("ref", json.string("#nonexistent")),
    ])

  let data = json.string("test")

  reference.validate_data(data, ref_schema, ctx)
  |> should.be_error
}

pub fn circular_reference_detection_test() {
  // Create lexicon with circular reference: A -> B -> A
  let defs =
    json.object([
      #(
        "refA",
        json.object([
          #("type", json.string("ref")),
          #("ref", json.string("#refB")),
        ]),
      ),
      #(
        "refB",
        json.object([
          #("type", json.string("ref")),
          #("ref", json.string("#refA")),
        ]),
      ),
    ])

  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.test.circular")),
      #("defs", defs),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([lexicon])

  let assert Ok(ctx) = context.build(builder)
  let ctx = context.with_current_lexicon(ctx, "app.test.circular")

  let ref_schema =
    json.object([#("type", json.string("ref")), #("ref", json.string("#refA"))])

  let data = json.string("test")

  // Should detect the circular reference and return an error
  reference.validate_data(data, ref_schema, ctx)
  |> should.be_error
}

pub fn nested_reference_chain_test() {
  // Create lexicon with nested references: A -> B -> string
  let defs =
    json.object([
      #(
        "refA",
        json.object([
          #("type", json.string("ref")),
          #("ref", json.string("#refB")),
        ]),
      ),
      #(
        "refB",
        json.object([
          #("type", json.string("ref")),
          #("ref", json.string("#actualString")),
        ]),
      ),
      #("actualString", json.object([#("type", json.string("string"))])),
    ])

  let lexicon =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.test.nested")),
      #("defs", defs),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([lexicon])

  let assert Ok(ctx) = context.build(builder)
  let ctx = context.with_current_lexicon(ctx, "app.test.nested")

  let ref_schema =
    json.object([#("type", json.string("ref")), #("ref", json.string("#refA"))])

  let data = json.string("Hello!")

  reference.validate_data(data, ref_schema, ctx)
  |> should.be_ok
}

pub fn cross_lexicon_reference_test() {
  // Create two lexicons where one references the other
  let lex1_defs =
    json.object([
      #(
        "userRef",
        json.object([
          #("type", json.string("ref")),
          #("ref", json.string("app.test.types#user")),
        ]),
      ),
    ])

  let lex2_defs =
    json.object([
      #(
        "user",
        json.object([
          #("type", json.string("object")),
          #(
            "properties",
            json.object([
              #(
                "id",
                json.object([
                  #("type", json.string("string")),
                  #("required", json.bool(True)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let lex1 =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.test.schema")),
      #("defs", lex1_defs),
    ])

  let lex2 =
    json.object([
      #("lexicon", json.int(1)),
      #("id", json.string("app.test.types")),
      #("defs", lex2_defs),
    ])

  let assert Ok(builder) =
    context.builder()
    |> context.with_validator(field.dispatch_data_validation)
    |> context.with_lexicons([lex1, lex2])

  let assert Ok(ctx) = context.build(builder)
  let ctx = context.with_current_lexicon(ctx, "app.test.schema")

  let ref_schema =
    json.object([
      #("type", json.string("ref")),
      #("ref", json.string("#userRef")),
    ])

  let data = json.object([#("id", json.string("user123"))])

  reference.validate_data(data, ref_schema, ctx)
  |> should.be_ok
}
