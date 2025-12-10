import gleeunit
import gleeunit/should
import honk/validation/formats

pub fn main() {
  gleeunit.main()
}

// ========== DATETIME TESTS ==========

pub fn datetime_valid_test() {
  formats.is_valid_rfc3339_datetime("2024-01-01T12:00:00Z") |> should.be_true
  formats.is_valid_rfc3339_datetime("2024-01-01T12:00:00+00:00")
  |> should.be_true
  formats.is_valid_rfc3339_datetime("2024-01-01T12:00:00.123Z")
  |> should.be_true
  formats.is_valid_rfc3339_datetime("2024-12-31T23:59:59-05:00")
  |> should.be_true
}

pub fn datetime_reject_negative_zero_timezone_test() {
  // Should reject -00:00 per ISO-8601 (must use +00:00)
  formats.is_valid_rfc3339_datetime("2024-01-01T12:00:00-00:00")
  |> should.be_false
}

pub fn datetime_max_length_test() {
  // 65 characters - should fail (max is 64)
  let long_datetime =
    "2024-01-01T12:00:00.12345678901234567890123456789012345678901234Z"
  formats.is_valid_rfc3339_datetime(long_datetime) |> should.be_false
}

pub fn datetime_invalid_date_test() {
  // February 30th doesn't exist - actual parsing should catch this
  formats.is_valid_rfc3339_datetime("2024-02-30T12:00:00Z") |> should.be_false
}

pub fn datetime_empty_string_test() {
  formats.is_valid_rfc3339_datetime("") |> should.be_false
}

// ========== HANDLE TESTS ==========

pub fn handle_valid_test() {
  formats.is_valid_handle("user.bsky.social") |> should.be_true
  formats.is_valid_handle("alice.example.com") |> should.be_true
  formats.is_valid_handle("test.co.uk") |> should.be_true
}

pub fn handle_reject_disallowed_tlds_test() {
  formats.is_valid_handle("user.local") |> should.be_false
  formats.is_valid_handle("server.arpa") |> should.be_false
  formats.is_valid_handle("example.invalid") |> should.be_false
  formats.is_valid_handle("app.localhost") |> should.be_false
  formats.is_valid_handle("service.internal") |> should.be_false
  formats.is_valid_handle("demo.example") |> should.be_false
  formats.is_valid_handle("site.onion") |> should.be_false
  formats.is_valid_handle("custom.alt") |> should.be_false
}

pub fn handle_max_length_test() {
  // 254 characters - should fail (max is 253)
  // Create: "a123456789" (10) + ".b123456789" (11) repeated = 254 total
  let segment = "a123456789b123456789c123456789d123456789e123456789"
  let long_handle =
    segment
    <> "."
    <> segment
    <> "."
    <> segment
    <> "."
    <> segment
    <> "."
    <> segment
    <> ".com"
  // This creates exactly 254 chars
  formats.is_valid_handle(long_handle) |> should.be_false
}

pub fn handle_requires_dot_test() {
  // Handle must have at least one dot (be a domain)
  formats.is_valid_handle("nodot") |> should.be_false
}

// ========== DID TESTS ==========

pub fn did_valid_test() {
  formats.is_valid_did("did:plc:z72i7hdynmk6r22z27h6tvur") |> should.be_true
  formats.is_valid_did("did:web:example.com") |> should.be_true
  formats.is_valid_did(
    "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK",
  )
  |> should.be_true
}

pub fn did_max_length_test() {
  // Create a DID longer than 2048 chars - should fail
  let long_did = "did:example:" <> string_repeat("a", 2040)
  formats.is_valid_did(long_did) |> should.be_false
}

pub fn did_invalid_ending_test() {
  // DIDs should not end with %
  formats.is_valid_did("did:example:foo%") |> should.be_false
}

pub fn did_empty_test() {
  formats.is_valid_did("") |> should.be_false
}

// ========== URI TESTS ==========

pub fn uri_valid_test() {
  formats.is_valid_uri("https://example.com") |> should.be_true
  formats.is_valid_uri("http://example.com/path") |> should.be_true
  formats.is_valid_uri("ftp://files.example.com") |> should.be_true
}

pub fn uri_max_length_test() {
  // Create a URI longer than 8192 chars - should fail
  let long_uri = "https://example.com/" <> string_repeat("a", 8180)
  formats.is_valid_uri(long_uri) |> should.be_false
}

pub fn uri_lowercase_scheme_test() {
  // Scheme must be lowercase
  formats.is_valid_uri("HTTP://example.com") |> should.be_false
  formats.is_valid_uri("HTTPS://example.com") |> should.be_false
}

pub fn uri_empty_test() {
  formats.is_valid_uri("") |> should.be_false
}

// ========== AT-URI TESTS ==========

pub fn at_uri_valid_test() {
  formats.is_valid_at_uri("at://did:plc:z72i7hdynmk6r22z27h6tvur")
  |> should.be_true
  formats.is_valid_at_uri(
    "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post",
  )
  |> should.be_true
  formats.is_valid_at_uri(
    "at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.post/3jui7kd54zh2y",
  )
  |> should.be_true
  formats.is_valid_at_uri("at://user.bsky.social/app.bsky.feed.post")
  |> should.be_true
}

pub fn at_uri_max_length_test() {
  // Create an AT-URI longer than 8192 chars - should fail
  let long_path = string_repeat("a", 8180)
  let long_at_uri = "at://did:plc:test/" <> long_path
  formats.is_valid_at_uri(long_at_uri) |> should.be_false
}

pub fn at_uri_invalid_collection_test() {
  // Collection must be a valid NSID (needs 3 segments)
  formats.is_valid_at_uri("at://did:plc:z72i7hdynmk6r22z27h6tvur/invalid")
  |> should.be_false
}

pub fn at_uri_empty_test() {
  formats.is_valid_at_uri("") |> should.be_false
}

// ========== TID TESTS ==========

pub fn tid_valid_test() {
  formats.is_valid_tid("3jui7kd54zh2y") |> should.be_true
  formats.is_valid_tid("2zzzzzzzzzzzy") |> should.be_true
}

pub fn tid_invalid_first_char_test() {
  // First char must be [234567abcdefghij], not k-z
  formats.is_valid_tid("kzzzzzzzzzzzz") |> should.be_false
  formats.is_valid_tid("lzzzzzzzzzzzz") |> should.be_false
  formats.is_valid_tid("zzzzzzzzzzzzz") |> should.be_false
}

pub fn tid_wrong_length_test() {
  formats.is_valid_tid("3jui7kd54zh2") |> should.be_false
  formats.is_valid_tid("3jui7kd54zh2yy") |> should.be_false
}

// ========== RECORD-KEY TESTS ==========

pub fn record_key_valid_test() {
  formats.is_valid_record_key("3jui7kd54zh2y") |> should.be_true
  formats.is_valid_record_key("my-custom-key") |> should.be_true
  formats.is_valid_record_key("key_with_underscores") |> should.be_true
  formats.is_valid_record_key("key:with:colons") |> should.be_true
}

pub fn record_key_reject_dot_test() {
  formats.is_valid_record_key(".") |> should.be_false
}

pub fn record_key_reject_dotdot_test() {
  formats.is_valid_record_key("..") |> should.be_false
}

pub fn record_key_max_length_test() {
  // 513 characters - should fail (max is 512)
  let long_key = string_repeat("a", 513)
  formats.is_valid_record_key(long_key) |> should.be_false
}

pub fn record_key_empty_test() {
  formats.is_valid_record_key("") |> should.be_false
}

// ========== CID TESTS ==========

pub fn cid_valid_test() {
  // CIDv1 examples (base32, base58)
  formats.is_valid_cid(
    "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
  )
  |> should.be_true
  formats.is_valid_cid(
    "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
  )
  |> should.be_true
  formats.is_valid_cid("QmQg1v4o9xdT3Q1R8tNK3z9ZkRmg7FbQfZ1J2Z3K4M5N6P")
  |> should.be_true
}

pub fn cid_reject_qmb_prefix_test() {
  // CIDv0 starting with "Qmb" not allowed per atproto spec
  formats.is_valid_cid("QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR")
  |> should.be_false
}

pub fn cid_min_length_test() {
  // 7 characters - should fail (min is 8)
  formats.is_valid_cid("abc1234") |> should.be_false
}

pub fn cid_max_length_test() {
  // 257 characters - should fail (max is 256)
  let long_cid = string_repeat("a", 257)
  formats.is_valid_cid(long_cid) |> should.be_false
}

pub fn cid_invalid_chars_test() {
  // Contains invalid characters
  formats.is_valid_cid("bafybei@invalid!") |> should.be_false
  formats.is_valid_cid("bafy bei space") |> should.be_false
}

pub fn cid_empty_test() {
  formats.is_valid_cid("") |> should.be_false
}

// ========== RAW CID TESTS ==========

// Test valid raw CID (bafkrei prefix = CIDv1 + raw multicodec 0x55)
pub fn valid_raw_cid_test() {
  formats.is_valid_raw_cid(
    "bafkreigh2akiscaildcqabsyg3dfr6chu3fgpregiymsck7e7aqa4s52zy",
  )
  |> should.be_true
}

// Test dag-cbor CID rejected (bafyrei prefix = CIDv1 + dag-cbor multicodec 0x71)
pub fn invalid_raw_cid_dag_cbor_test() {
  formats.is_valid_raw_cid(
    "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludirz2a",
  )
  |> should.be_false
}

// Test CIDv0 rejected for raw CID
pub fn invalid_raw_cid_v0_test() {
  formats.is_valid_raw_cid("QmbWqxBEKC3P8tqsKc98xmWNzrzDtRLMiMPL8wBuTGsMnR")
  |> should.be_false
}

// Test invalid CID rejected
pub fn invalid_raw_cid_garbage_test() {
  formats.is_valid_raw_cid("not-a-cid")
  |> should.be_false
}

// ========== LANGUAGE TESTS ==========

pub fn language_valid_test() {
  formats.is_valid_language_tag("en") |> should.be_true
  formats.is_valid_language_tag("en-US") |> should.be_true
  formats.is_valid_language_tag("zh-Hans-CN") |> should.be_true
  formats.is_valid_language_tag("i-enochian") |> should.be_true
}

pub fn language_max_length_test() {
  // 129 characters - should fail (max is 128)
  let long_tag = "en-" <> string_repeat("a", 126)
  formats.is_valid_language_tag(long_tag) |> should.be_false
}

pub fn language_empty_test() {
  formats.is_valid_language_tag("") |> should.be_false
}

// ========== HELPER FUNCTIONS ==========

fn string_repeat(s: String, n: Int) -> String {
  case n <= 0 {
    True -> ""
    False -> s <> string_repeat(s, n - 1)
  }
}
