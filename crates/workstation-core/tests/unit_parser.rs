//! # Tier 1: Unit Testing - Parser Grammar & AST Invariants
//!
//! Validates the strict, deterministic string parser for environment variable
//! keys, quote balance, and comment/whitespace stripping.
//!
//! ## Invariants Under Test
//! - POSIX identifier names must strictly conform to `^[A-Za-z_][A-Za-z0-9_]*$`.
//! - Surrounding quotes (`"` or `'`) must be balanced; unbalanced quotes fail closed.
//! - Empty assignments (`KEY=`) and comments (`# ...`) are handled deterministically.
//!
//! ## Falsifiability
//! Any tolerance of shell meta-characters or malformed syntax immediately fails the test suite.

use workstation_core::SecretStore;

// -----------------------------------------------------------------------------
// Section 1: POSIX Identifier Boundary Assertions
// -----------------------------------------------------------------------------

/// Tests valid and invalid environment variable key names against POSIX standards.
///
/// # Invariant Tested
/// Variable names must strictly begin with an ASCII letter or underscore, followed by
/// ASCII alphanumeric characters or underscores.
///
/// # Falsification Condition
/// Fails if invalid identifiers (e.g., starting with numbers, dashes, spaces, or Unicode)
/// are accepted into the secret store.
#[test]
fn test_posix_identifier_boundaries() {
    let mut store = SecretStore::new();

    // Valid identifiers that must pass
    let valid_payload = r#"
    VALID_KEY_1="val1"
    _INTERNAL_SECRET="val2"
    key_lowercase="val3"
    A=1
    "#;
    assert!(
        store.parse_str(valid_payload, "valid.env").is_ok(),
        "Valid POSIX identifiers should be parsed successfully"
    );
    assert_eq!(store.entries.len(), 4);

    // Invalid identifiers that must fail
    let invalid_keys = [
        "123_STARTS_WITH_NUM=val",
        "-DASH_PREFIX=val",
        "KEY-WITH-DASHES=val",
        "KEY WITH SPACES=val",
        "KEY.WITH.DOTS=val",
        "KEY@SPECIAL=val",
        "VÀR_UNICODE=val",
    ];

    for invalid in invalid_keys {
        let mut test_store = SecretStore::new();
        assert!(
            test_store.parse_str(invalid, "invalid.env").is_err(),
            "Identifier '{}' violates POSIX grammar and must be rejected",
            invalid
        );
    }
}

// -----------------------------------------------------------------------------
// Section 2: Quotation Sanitization & Boundary Matrix
// -----------------------------------------------------------------------------

/// Tests paired quotation stripping and unclosed quote detection.
///
/// # Invariant Tested
/// Values wrapped in balanced double quotes (`"..."`) or single quotes (`'...'`) must have
/// the outer quotes stripped. Unclosed or mismatched quotes must fail closed.
///
/// # Falsification Condition
/// Fails if unclosed quotes (`KEY="secret`) parse without error, or if interior quotes
/// are erroneously stripped.
#[test]
fn test_quote_sanitization_matrix() {
    let mut store = SecretStore::new();

    let payload = r#"
    DOUBLE_QUOTED="hello world"
    SINGLE_QUOTED='single string'
    UNQUOTED_VAL=simple_token_123
    NESTED_DOUBLE='has "interior" double'
    NESTED_SINGLE="has 'interior' single"
    "#;
    store
        .parse_str(payload, "quotes.env")
        .expect("Valid quoted values must parse");

    assert_eq!(store.entries.get("DOUBLE_QUOTED").unwrap().0, "hello world");
    assert_eq!(
        store.entries.get("SINGLE_QUOTED").unwrap().0,
        "single string"
    );
    assert_eq!(
        store.entries.get("UNQUOTED_VAL").unwrap().0,
        "simple_token_123"
    );
    assert_eq!(
        store.entries.get("NESTED_DOUBLE").unwrap().0,
        "has \"interior\" double"
    );
    assert_eq!(
        store.entries.get("NESTED_SINGLE").unwrap().0,
        "has 'interior' single"
    );

    // Malformed quotation test cases
    let malformed_payloads = [
        "UNCLOSED_DOUBLE=\"starts but never ends",
        "UNCLOSED_SINGLE='starts but never ends",
        "MISMATCHED_QUOTES=\"starts double ends single'",
        "REVERSED_MISMATCH='starts single ends double\"",
    ];

    for malformed in malformed_payloads {
        let mut err_store = SecretStore::new();
        assert!(
            err_store.parse_str(malformed, "malformed.env").is_err(),
            "Payload '{}' has unbalanced quotes and must fail closed",
            malformed
        );
    }
}

// -----------------------------------------------------------------------------
// Section 3: Whitespace, Comments, and Empty Values
// -----------------------------------------------------------------------------

/// Tests empty variable assignments, inline comments, and whitespace normalization.
///
/// # Invariant Tested
/// Empty assignments (`KEY=`) are permissible as empty strings. Leading/trailing whitespace
/// is normalized, and commented lines are completely ignored.
///
/// # Falsification Condition
/// Fails if an empty assignment triggers an error or if comments pollute the store.
#[test]
fn test_empty_and_whitespace_values() {
    let mut store = SecretStore::new();

    let payload = r#"
    # This is a full comment line
       # Indented comment line
    EMPTY_VAR=
    EMPTY_QUOTED=""
    EMPTY_SINGLE=''
    WHITESPACE_VAR="   spaced   "
    export EXPORT_PREFIXED="active"
    "#;
    store
        .parse_str(payload, "empty.env")
        .expect("Payload must parse cleanly");

    assert_eq!(store.entries.get("EMPTY_VAR").unwrap().0, "");
    assert_eq!(store.entries.get("EMPTY_QUOTED").unwrap().0, "");
    assert_eq!(store.entries.get("EMPTY_SINGLE").unwrap().0, "");
    assert_eq!(
        store.entries.get("WHITESPACE_VAR").unwrap().0,
        "   spaced   "
    );
    assert_eq!(store.entries.get("EXPORT_PREFIXED").unwrap().0, "active");
}
