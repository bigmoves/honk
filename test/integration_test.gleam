import gleam/json
import gleeunit
import gleeunit/should
import honk/validation/context
import honk/validation/primary/record

pub fn main() {
  gleeunit.main()
}

// Test complete record with nested objects and arrays
pub fn complex_record_test() {
  let schema =
    json.object([
      #("type", json.string("record")),
      #("key", json.string("tid")),
      #(
        "record",
        json.object([
          #("type", json.string("object")),
          #(
            "required",
            json.array([json.string("title"), json.string("tags")], fn(x) { x }),
          ),
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
              #("description", json.object([#("type", json.string("string"))])),
              #(
                "tags",
                json.object([
                  #("type", json.string("array")),
                  #("items", json.object([#("type", json.string("string"))])),
                  #("maxLength", json.int(10)),
                ]),
              ),
              #(
                "metadata",
                json.object([
                  #("type", json.string("object")),
                  #(
                    "properties",
                    json.object([
                      #(
                        "views",
                        json.object([#("type", json.string("integer"))]),
                      ),
                      #(
                        "published",
                        json.object([#("type", json.string("boolean"))]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = record.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test valid complex record data
pub fn complex_record_data_test() {
  let schema =
    json.object([
      #("type", json.string("record")),
      #("key", json.string("tid")),
      #(
        "record",
        json.object([
          #("type", json.string("object")),
          #("required", json.array([json.string("title")], fn(x) { x })),
          #(
            "properties",
            json.object([
              #("title", json.object([#("type", json.string("string"))])),
              #(
                "tags",
                json.object([
                  #("type", json.string("array")),
                  #("items", json.object([#("type", json.string("string"))])),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let data =
    json.object([
      #("title", json.string("My Post")),
      #(
        "tags",
        json.array([json.string("tech"), json.string("gleam")], fn(x) { x }),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = record.validate_data(data, schema, ctx)
  result |> should.be_ok
}

// Test record data missing required field
pub fn complex_record_missing_required_test() {
  let schema =
    json.object([
      #("type", json.string("record")),
      #("key", json.string("tid")),
      #(
        "record",
        json.object([
          #("type", json.string("object")),
          #("required", json.array([json.string("title")], fn(x) { x })),
          #(
            "properties",
            json.object([
              #("title", json.object([#("type", json.string("string"))])),
            ]),
          ),
        ]),
      ),
    ])

  let data = json.object([#("description", json.string("No title"))])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = record.validate_data(data, schema, ctx)
  result |> should.be_error
}

// Test deeply nested object structure
pub fn deeply_nested_object_test() {
  let schema =
    json.object([
      #("type", json.string("record")),
      #("key", json.string("any")),
      #(
        "record",
        json.object([
          #("type", json.string("object")),
          #(
            "properties",
            json.object([
              #(
                "level1",
                json.object([
                  #("type", json.string("object")),
                  #(
                    "properties",
                    json.object([
                      #(
                        "level2",
                        json.object([
                          #("type", json.string("object")),
                          #(
                            "properties",
                            json.object([
                              #(
                                "level3",
                                json.object([#("type", json.string("string"))]),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = record.validate_schema(schema, ctx)
  result |> should.be_ok
}

// Test array of arrays
pub fn array_of_arrays_test() {
  let schema =
    json.object([
      #("type", json.string("record")),
      #("key", json.string("tid")),
      #(
        "record",
        json.object([
          #("type", json.string("object")),
          #(
            "properties",
            json.object([
              #(
                "matrix",
                json.object([
                  #("type", json.string("array")),
                  #(
                    "items",
                    json.object([
                      #("type", json.string("array")),
                      #(
                        "items",
                        json.object([#("type", json.string("integer"))]),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build
  let result = record.validate_schema(schema, ctx)
  result |> should.be_ok
}
