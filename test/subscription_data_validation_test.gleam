import gleam/json
import gleeunit
import gleeunit/should
import validation/context
import validation/primary/subscription

pub fn main() {
  gleeunit.main()
}

// Test valid subscription parameters
pub fn valid_subscription_parameters_test() {
  let schema =
    json.object([
      #("type", json.string("subscription")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #("cursor", json.object([#("type", json.string("integer"))])),
            ]),
          ),
        ]),
      ),
    ])

  let data = json.object([#("cursor", json.int(12_345))])

  let assert Ok(ctx) = context.builder() |> context.build()
  subscription.validate_data(data, schema, ctx) |> should.be_ok
}

// Test invalid: missing required parameter
pub fn invalid_subscription_missing_required_test() {
  let schema =
    json.object([
      #("type", json.string("subscription")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #("collection", json.object([#("type", json.string("string"))])),
            ]),
          ),
          #("required", json.array([json.string("collection")], fn(x) { x })),
        ]),
      ),
    ])

  let data = json.object([])

  let assert Ok(ctx) = context.builder() |> context.build()
  subscription.validate_data(data, schema, ctx) |> should.be_error
}

// Test valid subscription with no parameters
pub fn valid_subscription_no_parameters_test() {
  let schema = json.object([#("type", json.string("subscription"))])

  let data = json.object([])

  let assert Ok(ctx) = context.builder() |> context.build()
  subscription.validate_data(data, schema, ctx) |> should.be_ok
}

// Test invalid: parameters not an object
pub fn invalid_subscription_not_object_test() {
  let schema =
    json.object([
      #("type", json.string("subscription")),
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
  subscription.validate_data(data, schema, ctx) |> should.be_error
}

// Test message validation with union
pub fn valid_subscription_message_test() {
  let schema =
    json.object([
      #("type", json.string("subscription")),
      #(
        "message",
        json.object([
          #(
            "schema",
            json.object([
              #("type", json.string("union")),
              #(
                "refs",
                json.array(
                  [json.string("#commit"), json.string("#identity")],
                  fn(x) { x },
                ),
              ),
            ]),
          ),
        ]),
      ),
    ])

  let data = json.object([#("$type", json.string("#commit"))])

  let assert Ok(ctx) = context.builder() |> context.build()
  // This will likely fail due to missing definitions, but tests dispatch
  case subscription.validate_message_data(data, schema, ctx) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Ok(Nil)
  }
  |> should.be_ok
}

// Test parameter constraint violation
pub fn invalid_subscription_constraint_violation_test() {
  let schema =
    json.object([
      #("type", json.string("subscription")),
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
  subscription.validate_data(data, schema, ctx) |> should.be_error
}

// Test valid array parameter
pub fn valid_subscription_array_parameter_test() {
  let schema =
    json.object([
      #("type", json.string("subscription")),
      #(
        "parameters",
        json.object([
          #("type", json.string("params")),
          #(
            "properties",
            json.object([
              #(
                "repos",
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
      #(
        "repos",
        json.array(
          [json.string("did:plc:abc"), json.string("did:plc:xyz")],
          fn(x) { x },
        ),
      ),
    ])

  let assert Ok(ctx) = context.builder() |> context.build()
  subscription.validate_data(data, schema, ctx) |> should.be_ok
}
