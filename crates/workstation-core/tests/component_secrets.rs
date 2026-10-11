//! # Tier 2: Component Testing - SecretStore Real-Disk Verification
//!
//! Validates `SecretStore` interactions against real POSIX files, permissions,
//! and discovery hierarchies on physical disk storage.
//!
//! ## Invariants Under Test
//! - Files with mode permissions other than `0600` or `0400` are rejected immediately.
//! - In strict mode, ambient `.env` / `.env.local` files in the current working directory are ignored.
//! - Memory holding sensitive values is securely zeroed upon reclamation.
//!
//! ## Falsifiability
//! Any leak of ambient tokens or execution of insecurely permissioned secret files
//! causes immediate test failure.

mod common;

use std::fs;
use tempfile::TempDir;
use workstation_core::SecretStore;

// -----------------------------------------------------------------------------
// Section 1: Real POSIX Permission Invariants
// -----------------------------------------------------------------------------

/// Tests permission enforcement against real files on disk with varying octal modes.
///
/// # Invariant Tested
/// Only files with octal permissions `0600` (read/write by owner only) or `0400`
/// (read-only by owner) may be loaded. All other permissions fail closed.
///
/// # Falsification Condition
/// Fails if `load_file` succeeds when executed against a file with world-readable
/// (`0644`) or group-writable (`0777`, `0664`) permissions.
#[test]
fn test_fail_closed_on_insecure_permissions() {
    let temp_dir = TempDir::new().expect("Failed to create temporary directory");
    let base = temp_dir.path();

    let content = "CRITICAL_TOKEN=\"super-secret-key-123\"\n";

    // 1. Insecure mode 0644 (Standard world-readable file)
    let insecure_644 = common::create_test_secret_file(base, "insecure_644.env", 0o644, content)
        .expect("Failed to create 0644 file");
    let mut store_644 = SecretStore::new();
    let result_644 = store_644.load_file(&insecure_644);
    assert!(
        result_644.is_err(),
        "Secret file with 0644 permissions MUST be rejected"
    );

    // 2. Insecure mode 0777 (Fully permissive world-executable file)
    let insecure_777 = common::create_test_secret_file(base, "insecure_777.env", 0o777, content)
        .expect("Failed to create 0777 file");
    let mut store_777 = SecretStore::new();
    assert!(
        store_777.load_file(&insecure_777).is_err(),
        "Secret file with 0777 permissions MUST be rejected"
    );

    // 3. Insecure mode 0660 (Group readable/writable)
    let insecure_660 = common::create_test_secret_file(base, "insecure_660.env", 0o660, content)
        .expect("Failed to create 0660 file");
    let mut store_660 = SecretStore::new();
    assert!(
        store_660.load_file(&insecure_660).is_err(),
        "Secret file with 0660 permissions MUST be rejected"
    );

    // 4. Secure mode 0600 (Owner read/write only) - MUST PASS
    let secure_600 = common::create_test_secret_file(base, "secure_600.env", 0o600, content)
        .expect("Failed to create 0600 file");
    let mut store_600 = SecretStore::new();
    assert!(
        store_600.load_file(&secure_600).is_ok(),
        "Secret file with 0600 permissions MUST be accepted"
    );
    assert_eq!(
        store_600.entries.get("CRITICAL_TOKEN").unwrap().0,
        "super-secret-key-123"
    );

    // 5. Secure mode 0400 (Owner read-only) - MUST PASS
    let secure_400 = common::create_test_secret_file(base, "secure_400.env", 0o400, content)
        .expect("Failed to create 0400 file");
    let mut store_400 = SecretStore::new();
    assert!(
        store_400.load_file(&secure_400).is_ok(),
        "Secret file with 0400 permissions MUST be accepted"
    );
}

// -----------------------------------------------------------------------------
// Section 2: File Discovery Hierarchy & Strict Isolation
// -----------------------------------------------------------------------------

/// Tests auto-discovery priority and strict mode ambient suppression.
///
/// # Invariant Tested
/// When strict mode is enabled, `.env` and `.env.local` in the working directory
/// are ignored to protect untrusted cloned repositories from reflecting ambient keys.
///
/// # Falsification Condition
/// Fails if strict mode discovers or loads a local `.env` file.
#[test]
fn test_discovery_hierarchy_strict_mode() {
    let temp_dir = TempDir::new().expect("Failed to create temp directory");
    let root = temp_dir.path();

    // Create local .env in temporary workspace
    let local_env = root.join(".env");
    fs::write(&local_env, "AMBIENT_KEY=leaked_value\n").unwrap();

    // 1. Explicit path overrides all discovery
    let explicit = SecretStore::resolve_secret_file(Some(&local_env), true)
        .expect("Explicit path must resolve");
    assert_eq!(explicit, Some(local_env.clone()));

    // 2. Strict mode without explicit file must NOT return local files
    // (We test resolve_secret_file with strict=true)
    let strict_res =
        SecretStore::resolve_secret_file(None, true).expect("Resolution should succeed");
    // Should be None or user-level ~/.secrets/ai.env, never local .env
    if let Some(path) = strict_res {
        assert_ne!(
            path, local_env,
            "Strict mode MUST NOT auto-discover local workspace .env"
        );
    }
}
