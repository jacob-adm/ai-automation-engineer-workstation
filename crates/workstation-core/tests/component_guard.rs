//! # Tier 2: Component Testing - Circuit Breaker & Sentinel Invariants
//!
//! Validates `GuardManager` sentinel file creation, permission enforcement,
//! and emergency circuit-breaker trip/resume lifecycle.
//!
//! ## Invariants Under Test
//! - `guard stop` creates a sentinel file with strict `0600` permissions.
//! - When the sentinel exists, `assert_permitted()` strictly aborts execution.
//! - `guard resume` securely validates ownership before removing the sentinel.
//!
//! ## Falsifiability
//! Any ability to bypass the sentinel while engaged constitutes a critical test failure.

mod common;

use std::fs;
use std::os::unix::fs::PermissionsExt;
use workstation_core::GuardManager;

// -----------------------------------------------------------------------------
// Section 1: Circuit Breaker Lifecycle Assertions
// -----------------------------------------------------------------------------

/// Tests the complete emergency stop, assert, and resume lifecycle.
///
/// # Invariant Tested
/// The sentinel file `$HOME/.agent_stop` must exist with `0600` permissions when stopped,
/// block agent runs, and permit execution once cleared.
///
/// # Falsification Condition
/// Fails if `assert_permitted` returns `Ok` while the stop sentinel exists.
#[test]
fn test_circuit_breaker_full_lifecycle() {
    let temp_home = common::create_test_home().expect("Failed to create sandbox HOME");
    let home_path = temp_home.path();

    // Point HOME to isolated temp directory for test execution
    std::env::set_var("HOME", home_path);

    let guard = GuardManager::new();

    // 1. Initial state: Circuit breaker must be clear
    assert!(!guard.status(), "Circuit breaker should initially be clear");
    assert!(
        guard.assert_permitted().is_ok(),
        "Agent execution must be permitted initially"
    );

    // 2. Engage Emergency Stop
    guard.stop().expect("Failed to engage emergency stop");
    assert!(guard.status(), "Circuit breaker must report engaged");
    assert!(
        guard.assert_permitted().is_err(),
        "Agent execution MUST be rejected when circuit breaker is active"
    );

    // Verify file exists and has 0600 permissions
    let sentinel = home_path.join(".agent_stop");
    assert!(
        sentinel.is_file(),
        "Sentinel file must physically exist on disk"
    );
    let mode = fs::metadata(&sentinel).unwrap().permissions().mode() & 0o777;
    assert_eq!(mode, 0o600, "Sentinel file MUST have 0600 permissions");

    // 3. Clear Emergency Stop
    guard.resume().expect("Failed to resume circuit breaker");
    assert!(
        !guard.status(),
        "Circuit breaker should report clear after resume"
    );
    assert!(
        !sentinel.exists(),
        "Sentinel file must be deleted upon resume"
    );
    assert!(
        guard.assert_permitted().is_ok(),
        "Agent execution must be permitted after resume"
    );
}
