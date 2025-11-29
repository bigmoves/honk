# Changelog

## 1.1.0

### Added

- Add `ValidationContext` type for external use
- Add `build_validation_context` function to build a reusable validation context from lexicons
- Add `validate_record_with_context` function for faster batch validation using a pre-built context

## 1.0.1

### Fixed

- Fix `is_null_dynamic` to use `dynamic.classify` for consistent null detection

## 1.0.0

- Initial release
