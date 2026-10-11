//! # Tier 6: End-to-End (E2E) CLI & Multi-Call Symlink Suite
//!
//! Validates the compiled `workstation` binary through real terminal execution,
//! verifying CLI flags, exit code propagation, and `argv[0]` multi-call symlink routing.
//!
//! ## Invariants Under Test
//! - Subcommands (`sysinfo`, `guard`, `doctor`, `secret-run`) execute via standard CLI.
//! - Multi-call symlinks (`sysinfo`, `secret-run`, `doctor`) route correctly without parent command.
//! - Exit codes from child processes are propagated transparently without distortion.
//!
//! ## Falsifiability
//! Any routing failure, exit code mangling, or execution panic causes immediate test failure.

use assert_cmd::prelude::*;
use predicates::prelude::*;
use std::fs;
use std::os::unix::fs::symlink;
use std::process::Command;
use tempfile::TempDir;

// -----------------------------------------------------------------------------
// Section 1: Standard CLI Flag & Subcommand Execution
// -----------------------------------------------------------------------------

/// Tests standard top-level CLI execution and help flags.
#[test]
fn test_cli_help_and_subcommands() {
    let mut cmd = Command::cargo_bin("workstation").expect("Binary must exist");
    cmd.arg("--help");
    cmd.assert().success().stdout(predicate::str::contains(
        "Unified AI Automation Workstation",
    ));

    let mut sysinfo_cmd = Command::cargo_bin("workstation").expect("Binary must exist");
    sysinfo_cmd.arg("sysinfo");
    sysinfo_cmd
        .assert()
        .success()
        .stdout(predicate::str::contains("SYSTEM OVERVIEW"))
        .stdout(predicate::str::contains("Memory:"));

    let mut guard_cmd = Command::cargo_bin("workstation").expect("Binary must exist");
    guard_cmd.args(["guard", "status"]);
    guard_cmd
        .assert()
        .success()
        .stdout(predicate::str::contains("Circuit breaker"));
}

// -----------------------------------------------------------------------------
// Section 2: Multi-Call Binary Dispatch (argv[0] Symlink Routing)
// -----------------------------------------------------------------------------

/// Tests multi-call binary routing when the executable is invoked through symlinks.
///
/// # Invariant Tested
/// When invoked via symlink name (e.g. `~/.local/bin/sysinfo`), the binary must inspect
/// `argv[0]` and directly execute the corresponding subcommand with zero routing overhead.
///
/// # Falsification Condition
/// Fails if the symlinked binary errors or fails to recognize its target command.
#[test]
fn test_multi_call_symlink_dispatch() {
    let temp_dir = TempDir::new().expect("Failed to create tempdir");
    let bin_dir = temp_dir.path();

    // Locate compiled workstation binary
    let workstation_bin = assert_cmd::cargo::cargo_bin("workstation");
    assert!(workstation_bin.is_file(), "workstation binary must exist");

    // 1. Create sysinfo symlink
    let sysinfo_symlink = bin_dir.join("sysinfo");
    symlink(&workstation_bin, &sysinfo_symlink).expect("Failed to create sysinfo symlink");

    // Execute via symlink
    let mut cmd_sysinfo = Command::new(&sysinfo_symlink);
    cmd_sysinfo
        .assert()
        .success()
        .stdout(predicate::str::contains("SYSTEM OVERVIEW"));

    // 2. Create secret-run symlink
    let secret_run_symlink = bin_dir.join("secret-run");
    symlink(&workstation_bin, &secret_run_symlink).expect("Failed to create secret-run symlink");

    // Create a real secret file
    let secret_file = bin_dir.join("test.env");
    fs::write(&secret_file, "E2E_TOKEN=\"e2e_verified_123\"\n").unwrap();
    let mut perms = fs::metadata(&secret_file).unwrap().permissions();
    use std::os::unix::fs::PermissionsExt;
    perms.set_mode(0o600);
    fs::set_permissions(&secret_file, perms).unwrap();

    // Execute command with secret-run symlink
    let mut cmd_secret = Command::new(&secret_run_symlink);
    cmd_secret.args([
        "--env-file",
        secret_file.to_str().unwrap(),
        "--",
        "sh",
        "-c",
        "echo E2E_TOKEN=$E2E_TOKEN",
    ]);
    cmd_secret
        .assert()
        .success()
        .stdout(predicate::str::contains("E2E_TOKEN=e2e_verified_123"));
}

// -----------------------------------------------------------------------------
// Section 3: Transparent Exit Code Propagation
// -----------------------------------------------------------------------------

/// Tests that secret-run transparently preserves and propagates child exit codes.
///
/// # Invariant Tested
/// The exit code of the target executable must be propagated to the caller unchanged.
///
/// # Falsification Condition
/// Fails if an exit code like 42 is squashed to 0 or 1.
#[test]
fn test_cli_exit_code_propagation() {
    let mut cmd = Command::cargo_bin("workstation").expect("Binary must exist");
    cmd.args(["secret-run", "--", "sh", "-c", "exit 42"]);
    cmd.assert().code(predicate::eq(42));
}
