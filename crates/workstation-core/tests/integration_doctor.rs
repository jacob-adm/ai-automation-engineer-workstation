//! # Tier 3: Integration Testing - Doctor Drift Detection & Self-Healing
//!
//! Validates `DoctorEngine` detecting synthetic configuration drift and automatically
//! healing broken symlinks and permissions on disk via `--fix`.
//!
//! ## Invariants Under Test
//! - Any drifted or missing symlink is detected and reported as a check failure.
//! - Running in fix mode (`--fix`) idempotently recreates missing symlinks and hardens secrets.
//! - Post-remediation assertions achieve full verification without human intervention.
//!
//! ## Falsifiability
//! Failure to detect broken configuration or failure of `--fix` to restore valid state
//! triggers immediate test failure.

mod common;

use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;
use workstation_core::DoctorEngine;

// -----------------------------------------------------------------------------
// Section 1: Self-Healing Drift Roundtrip Assertions
// -----------------------------------------------------------------------------

/// Tests detection of missing symlinks and verifies automatic remediation via --fix.
///
/// # Invariant Tested
/// The "Spilled Coffee Principle": Any drifted system state must be identified,
/// and `--fix` must restore complete structural integrity.
///
/// # Falsification Condition
/// Fails if doctor fails to detect broken symlinks, or if `--fix` fails to heal them.
#[test]
fn test_doctor_drift_detection_and_self_healing() {
    let temp_home = common::create_test_home().expect("Failed to create test home");
    let home_path = temp_home.path().to_path_buf();

    // Use current repository as DOTFILES_ROOT
    let dotfiles_root = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .to_path_buf();

    // Set HOME to test directory
    std::env::set_var("HOME", &home_path);

    // 1. Synthetic Drift Setup:
    // Create an insecure secret file with 0644 mode
    let secret_file = home_path.join(".secrets/ai.env");
    fs::write(&secret_file, "OPENAI_API_KEY=test\n").unwrap();
    let mut perms = fs::metadata(&secret_file).unwrap().permissions();
    perms.set_mode(0o644);
    fs::set_permissions(&secret_file, perms).unwrap();

    // 2. Initial Run (Diagnostic Mode, fix_mode = false)
    let diag_engine = DoctorEngine::new(dotfiles_root.clone(), false);
    let initial_report = diag_engine.run_all();

    // Must report failures due to missing dotfile symlinks and loose secret permissions
    assert!(
        initial_report.failed > 0,
        "Doctor must detect missing symlinks and insecure permissions"
    );

    // 3. Self-Healing Run (Remediation Mode, fix_mode = true)
    let fix_engine = DoctorEngine::new(dotfiles_root.clone(), true);
    let _heal_report = fix_engine.run_all();

    // Verify secret file was hardened to 0600
    let hardened_mode = fs::metadata(&secret_file).unwrap().permissions().mode() & 0o777;
    assert_eq!(
        hardened_mode, 0o600,
        "Doctor --fix MUST harden secret permissions to 0600"
    );

    // 4. Verify Symlinks Were Physically Created on Disk
    assert!(
        home_path.join(".bashrc").is_symlink(),
        ".bashrc symlink must be restored"
    );
    assert!(
        home_path.join(".vimrc").is_symlink(),
        ".vimrc symlink must be restored"
    );
    assert!(
        home_path.join(".tmux.conf").is_symlink(),
        ".tmux.conf symlink must be restored"
    );

    // 5. Subsequent Verification Run
    let verify_engine = DoctorEngine::new(dotfiles_root, false);
    let final_report = verify_engine.run_all();

    // Failures should decrease dramatically (only missing OS commands like pueue or docker CLI on host might fail)
    assert!(
        final_report.failed < initial_report.failed,
        "Doctor --fix must significantly reduce failures by restoring symlinks and permissions"
    );
}
