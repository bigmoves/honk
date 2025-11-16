import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/primary/query

pub fn main() {
  gleeunit.main()
}

// Test valid query parameters
pub fn valid_query_parameters_test() {
  let schema =
    json.object([
      #("type", json.string("query")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #(
                "limit",
                json.object([
                  #("type", json.string("integer")),
                  #("minimum", json.int(1)),
                  #("maximum", json.int(100)),
                ]),
              ),
              #("cursor", json.object([#("type", json.string("string"))])),
            ]),
          ),
        ]),
      ),
    ])

  let data =
    json.object([#("limit", json.int(50)), #("cursor", json.string("abc123"))])

  let assert Ok(ctx) = context.builder() |> context.build()
  query.validate_data(data, schema, ctx) |> should.be_ok
}

// Test query with required parameter
pub fn valid_query_with_required_test() {
  let schema =
    json.object([
      #("type", json.string("query")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #("repo", json.object([#("type", json.string("string"))])),
            ]),
          ),
          #("required", json.array([json.string("repo")], fn(x) { x })),
        ]),
      ),
    ])

  let data = json.object([#("repo", json.string("did:plc:abc123"))])

  let assert Ok(ctx) = context.builder() |> context.build()
  query.validate_data(data, schema, ctx) |> should.be_ok
}

// Test invalid: missing required parameter
pub fn invalid_query_missing_required_test() {
  let schema =
    json.object([
      #("type", json.string("query")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #("repo", json.object([#("type", json.string("string"))])),
              #("collection", json.object([#("type", json.string("string"))])),
            ]),
          ),
          #("required", json.array([json.string("repo")], fn(x) { x })),
        ]),
      ),
    ])

  let data = json.object([#("collection", json.string("app.bsky.feed.post"))])

  let assert Ok(ctx) = context.builder() |> context.build()
  query.validate_data(data, schema, ctx) |> should.be_error
}

// Test invalid: wrong parameter type
pub fn invalid_query_wrong_type_test() {
  let schema =
    json.object([
      #("type", json.string("query")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #(
                "limit",
                json.object([
                  #("type", json.string("integer")),
                  #("minimum", json.int(1)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let data = json.object([#("limit", json.string("not-a-number"))])

  let assert Ok(ctx) = context.builder() |> context.build()
  query.validate_data(data, schema, ctx) |> should.be_error
}

// Test invalid: data not an object
pub fn invalid_query_not_object_test() {
  let schema =
    json.object([
      #("type", json.string("query")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #("properties", json.object([])),
        ]),
      ),
    ])

  let data = json.array([], fn(x) { x })

  let assert Ok(ctx) = context.builder() |> context.build()
  query.validate_data(data, schema, ctx) |> should.be_error
}

// Test parameter constraint violation
pub fn invalid_query_constraint_violation_test() {
  let schema =
    json.object([
      #("type", json.string("query")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #(
                "limit",
                json.object([
                  #("type", json.string("integer")),
                  #("maximum", json.int(100)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let data = json.object([#("limit", json.int(200))])

  let assert Ok(ctx) = context.builder() |> context.build()
  query.validate_data(data, schema, ctx) |> should.be_error
}

// Test array parameter
pub fn valid_query_array_parameter_test() {
  let schema =
    json.object([
      #("type", json.string("query")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #(
                "tags",
                json.object([
                  #("type", json.string("array")),
                  #(
                    "items",
                    json.object([
                      #("type", json.string("string")),
                      #("maxLength", json.int(50)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let data =
    json.object([
      #(
        "tags",
        json.array([json.string("tag1"), json.string("tag2")], fn(x) { x }),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build()
  query.validate_data(data, schema, ctx) |> should.be_ok
}

// Test query with no parameters
pub fn valid_query_no_parameters_test() {
  let schema = json.object([#("type", json.string("query"))])

  let data = json.object([])

  let assert Ok(ctx) = context.builder() |> context.build()
  query.validate_data(data, schema, ctx) |> should.be_ok
}
