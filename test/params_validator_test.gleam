import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/primary/params

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

// ==================== DATA VALIDATION TESTS ====================

// Test valid data with required parameters
pub fn valid_data_with_required_params_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("repo", json.object([#("type", json.string("string"))])),
          #("limit", json.object([#("type", json.string("integer"))])),
        ]),
      ),
      #(
        "required",
        json.array([json.string("repo"), json.string("limit")], fn(x) { x }),
      ),
    ])

  let data =
    json.object([
      #("repo", json.string("alice.bsky.social")),
      #("limit", json.int(50)),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_ok
}

// Test valid data with optional parameters
pub fn valid_data_with_optional_params_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("repo", json.object([#("type", json.string("string"))])),
          #("cursor", json.object([#("type", json.string("string"))])),
        ]),
      ),
      #("required", json.array([json.string("repo")], fn(x) { x })),
    ])

  // Data has required param but not optional cursor
  let data = json.object([#("repo", json.string("alice.bsky.social"))])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_ok
}

// Test valid data with all parameter types
pub fn valid_data_all_types_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("name", json.object([#("type", json.string("string"))])),
          #("count", json.object([#("type", json.string("integer"))])),
          #("enabled", json.object([#("type", json.string("boolean"))])),
          #("metadata", json.object([#("type", json.string("unknown"))])),
        ]),
      ),
    ])

  let data =
    json.object([
      #("name", json.string("test")),
      #("count", json.int(42)),
      #("enabled", json.bool(True)),
      #("metadata", json.object([#("key", json.string("value"))])),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_ok
}

// Test valid data with array parameter
pub fn valid_data_with_array_test() {
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
              #("items", json.object([#("type", json.string("string"))])),
            ]),
          ),
        ]),
      ),
    ])

  let data =
    json.object([
      #("tags", json.array([json.string("foo"), json.string("bar")], fn(x) {
        x
      })),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_ok
}

// Test invalid data: missing required parameter
pub fn invalid_data_missing_required_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("repo", json.object([#("type", json.string("string"))])),
          #("limit", json.object([#("type", json.string("integer"))])),
        ]),
      ),
      #("required", json.array([json.string("repo")], fn(x) { x })),
    ])

  // Data is missing required "repo" parameter
  let data = json.object([#("limit", json.int(50))])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_error
}

// Test invalid data: wrong type for parameter
pub fn invalid_data_wrong_type_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("limit", json.object([#("type", json.string("integer"))])),
        ]),
      ),
    ])

  // limit should be integer but is string
  let data = json.object([#("limit", json.string("not a number"))])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_error
}

// Test invalid data: string exceeds maxLength
pub fn invalid_data_string_too_long_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "name",
            json.object([
              #("type", json.string("string")),
              #("maxLength", json.int(5)),
            ]),
          ),
        ]),
      ),
    ])

  // name is longer than maxLength of 5
  let data = json.object([#("name", json.string("toolongname"))])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_error
}

// Test invalid data: integer below minimum
pub fn invalid_data_integer_below_minimum_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #(
            "count",
            json.object([
              #("type", json.string("integer")),
              #("minimum", json.int(1)),
            ]),
          ),
        ]),
      ),
    ])

  // count is below minimum of 1
  let data = json.object([#("count", json.int(0))])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_error
}

// Test invalid data: array with wrong item type
pub fn invalid_data_array_wrong_item_type_test() {
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
              #("items", json.object([#("type", json.string("integer"))])),
            ]),
          ),
        ]),
      ),
    ])

  // Array contains strings instead of integers
  let data =
    json.object([
      #("ids", json.array([json.string("one"), json.string("two")], fn(x) {
        x
      })),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_error
}

// Test valid data with no properties defined (empty schema)
pub fn valid_data_empty_schema_test() {
  let schema = json.object([#("type", json.string("params"))])

  let data = json.object([])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_ok
}

// Test valid data allows unknown parameters not in schema
pub fn valid_data_unknown_parameters_allowed_test() {
  let schema =
    json.object([
      #("type", json.string("params")),
      #(
        "properties",
        json.object([
          #("repo", json.object([#("type", json.string("string"))])),
        ]),
      ),
    ])

  // Data has "extra" parameter not in schema
  let data =
    json.object([
      #("repo", json.string("alice.bsky.social")),
      #("extra", json.string("allowed")),
    ])

  let assert Ok(c) = context.builder() |> context.build()
  params.validate_data(data, schema, c) |> should.be_ok
}
