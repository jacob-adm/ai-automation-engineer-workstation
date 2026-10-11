//! # Tier 4: Acceptance Testing - Behavioral System Contracts
//!
//! Validates core architectural guarantees specified in the system documentation:
//! - **Pillar 1: Zero-Ambient Credential Isolation**
//! - **Pillar 6: Self-Healing Declarative Idempotency & Backup Preservation**
//!
//! ## Invariants Under Test
//! - Parent processes retain zero ambient tokens after child execution.
//! - Non-symlink user files are preserved in timestamped backup archives before linking.
//!
//! ## Falsifiability
//! Any token presence in parent process memory or silent file overwrite constitutes contract breach.

mod common;

use std::fs;
use std::process::Command;
use workstation_core::{create_atomic_symlink, SecretStore};

// -----------------------------------------------------------------------------
// Section 1: Zero-Ambient Credential Isolation Contract
// -----------------------------------------------------------------------------

/// Tests that secrets loaded from a file exist ONLY in the child process environment,
/// leaving the parent process environment completely untainted.
///
/// # Invariant Tested
/// "Zero API keys in ambient shell profiles": tokens are injected strictly at the
/// child process boundary.
///
/// # Falsification Condition
/// Fails if the secret variable leaks into `std::env::var()` of the host process.
#[test]
fn test_contract_zero_ambient_credential_isolation() {
    let temp_home = common::create_test_home().unwrap();
    let secret_path = common::create_test_secret_file(
        temp_home.path(),
        "ai.env",
        0o600,
        "ISOLATED_SECRET_KEY=\"vault-token-xyz-987\"\n",
    )
    .unwrap();

    let mut store = SecretStore::new();
    store
        .load_file(&secret_path)
        .expect("Failed to load secret file");

    let secret_key = "ISOLATED_SECRET_KEY";
    let expected_val = "vault-token-xyz-987";

    // 1. Assert parent process environment does NOT contain secret
    assert!(
        std::env::var(secret_key).is_err(),
        "Secret token MUST NOT exist in parent process environment"
    );

    // 2. Spawn real child process and inject secret strictly into child
    let mut cmd = Command::new("sh");
    cmd.args(["-c", "printf '%s' \"$ISOLATED_SECRET_KEY\""]);
    for (k, v) in &store.entries {
        cmd.env(k, &v.0);
    }

    let output = cmd.output().expect("Failed to execute child process");
    let child_output = String::from_utf8(output.stdout).unwrap();

    // 3. Child process MUST observe the secret value
    assert_eq!(child_output, expected_val);

    // 4. Parent process MUST STILL be clean
    assert!(
        std::env::var(secret_key).is_err(),
        "Parent process environment MUST remain clean after child execution"
    );
}

// -----------------------------------------------------------------------------
// Section 2: Declarative Idempotency & Backup Preservation Contract
// -----------------------------------------------------------------------------

/// Tests that linking over existing user files archives them safely, and subsequent runs
/// are 100% idempotent.
///
/// # Invariant Tested
/// "The Spilled Coffee Principle": Zero silent data loss on existing dotfiles.
///
/// # Falsification Condition
/// Fails if an existing real file is deleted without backup, or if idempotent runs mutate state.
#[test]
fn test_contract_backup_preservation_and_idempotency() {
    let temp_target = common::create_test_home().unwrap();
    let target_dir = temp_target.path().to_path_buf();
    let backup_dir = target_dir.join(".dotfiles_backup");

    let source_dir = temp_target.path().join("sandbox_dotfiles");
    fs::create_dir_all(&source_dir).unwrap();
    let fixture_vimrc = source_dir.join(".vimrc");
    fs::write(&fixture_vimrc, "\" workstation managed vimrc\n").unwrap();

    // Create an existing real (non-symlink) user file at destination
    let user_vimrc = target_dir.join(".vimrc");
    fs::write(&user_vimrc, "\" user legacy custom config\n").unwrap();

    // 1. First run: Must backup user file and create symlink
    let created = create_atomic_symlink(&fixture_vimrc, &user_vimrc, &backup_dir, false)
        .expect("First link must succeed");
    assert!(created, "First run should create symlink");
    assert!(user_vimrc.is_symlink(), ".vimrc must now be a symlink");

    // Verify backup exists
    let backed_up_file = backup_dir.join(".vimrc");
    assert!(
        backed_up_file.is_file(),
        "Existing file must be safely backed up"
    );
    let backup_content = fs::read_to_string(backed_up_file).unwrap();
    assert_eq!(backup_content, "\" user legacy custom config\n");

    // 2. Second run: Idempotency check (Must perform zero mutations)
    let re_run = create_atomic_symlink(&fixture_vimrc, &user_vimrc, &backup_dir, false)
        .expect("Second link must succeed");
    assert!(!re_run, "Second run MUST be idempotent (zero mutations)");
}
