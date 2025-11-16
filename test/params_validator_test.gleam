import gleam/json
import gleeunit
import gleeunit/should
import validation/context
import validation/primary/params

pub fn main() {
  gleeunit.main()
}

// Test valid params with boolean property
pub fn valid_params_boolean_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "isPublic",
            json.object([
              #("type", json.string("boolean")),
              #("description", json.string("Whether the item is public")),
            ]),
          ),
        ]),
      ),
    ])

  let ctx = context.builder() |> context.build()
  case ctx {
    Ok(c) -> params.validate_schema(schema, c) |> should.be_ok
    Error(_) -> should.fail()
  }
}

// Test valid params with multiple property types
pub fn valid_params_multiple_types_test() {
  let schema =
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
          #(
            "cursor",
            json.object([
              #("type", json.string("string")),
              #("description", json.string("Pagination cursor")),
            ]),
          ),
          #("includeReplies", json.object([#("type", json.string("boolean"))])),
        ]),
      ),
    ])

  let ctx = context.builder() |> context.build()
  case ctx {
    Ok(c) -> params.validate_schema(schema, c) |> should.be_ok
    Error(_) -> should.fail()
  }
}

// Test valid params with array property
pub fn valid_params_with_array_test() {
  let schema =
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
    ])

  let ctx = context.builder() |> context.build()
  case ctx {
    Ok(c) -> params.validate_schema(schema, c) |> should.be_ok
    Error(_) -> should.fail()
  }
}

// Test valid params with required fields
pub fn valid_params_with_required_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "repo",
            json.object([
              #("type", json.string("string")),
              #("format", json.string("at-identifier")),
            ]),
          ),
          #(
            "collection",
            json.object([
              #("type", json.string("string")),
              #("format", json.string("nsid")),
            ]),
          ),
        ]),
      ),
      #("required", json.array([json.string("repo")], fn(x) { x })),
    ])

  let ctx = context.builder() |> context.build()
  case ctx {
    Ok(c) -> params.validate_schema(schema, c) |> should.be_ok
    Error(_) -> should.fail()
  }
}

// Test valid params with unknown type
pub fn valid_params_with_unknown_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("metadata", json.object([#("type", json.string("unknown"))])),
        ]),
      ),
    ])

  let ctx = context.builder() |> context.build()
  case ctx {
    Ok(c) -> params.validate_schema(schema, c) |> should.be_ok
    Error(_) -> should.fail()
  }
}

// Test invalid: params with object property (not allowed)
pub fn invalid_params_object_property_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "filter",
            json.object([
              #("type", json.string("object")),
              #("properties", json.object([])),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_schema(schema, c) |> should.be_error
}

// Test invalid: params with blob property (not allowed)
pub fn invalid_params_blob_property_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "avatar",
            json.object([
              #("type", json.string("blob")),
              #("accept", json.array([json.string("image/*")], fn(x) { x })),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_schema(schema, c) |> should.be_error
}

// Test invalid: required field not in properties
pub fn invalid_params_required_not_in_properties_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("limit", json.object([#("type", json.string("integer"))])),
        ]),
      ),
      #("required", json.array([json.string("cursor")], fn(x) { x })),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_schema(schema, c) |> should.be_error
}

// Test invalid: empty property name
pub fn invalid_params_empty_property_name_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("", json.object([#("type", json.string("string"))])),
        ]),
      ),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_schema(schema, c) |> should.be_error
}

// Test invalid: array with object items (not allowed)
pub fn invalid_params_array_of_objects_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "filters",
            json.object([
              #("type", json.string("array")),
              #(
                "items",
                json.object([
                  #("type", json.string("object")),
                  #("properties", json.object([])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_schema(schema, c) |> should.be_error
}

// Test invalid: wrong type (not "params")
pub fn invalid_params_wrong_type_test() {
  let schema =
    json.object([
      #("type", json.string("object")),
      #("properties", json.object([])),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_schema(schema, c) |> should.be_error
}

// Test valid: array of integers
pub fn valid_params_array_of_integers_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "ids",
            json.object([
              #("type", json.string("array")),
              #(
                "items",
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

  let ctx = context.builder() |> context.build()
  case ctx {
    Ok(c) -> params.validate_schema(schema, c) |> should.be_ok
    Error(_) -> should.fail()
  }
}

// Test valid: array of unknown
pub fn valid_params_array_of_unknown_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "data",
            json.object([
              #("type", json.string("array")),
              #("items", json.object([#("type", json.string("unknown"))])),
            ]),
          ),
        ]),
      ),
    ])

  let ctx = context.builder() |> context.build()
  case ctx {
    Ok(c) -> params.validate_schema(schema, c) |> should.be_ok
    Error(_) -> should.fail()
  }
}
