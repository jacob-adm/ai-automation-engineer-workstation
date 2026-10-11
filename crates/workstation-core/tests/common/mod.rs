#![allow(dead_code)]
//! # Zero-Theatre Test Harness Primitives
//!
//! Provides factory constructors for real POSIX files, real Git repositories,
//! and real sandbox directory hierarchies. No mocks or stubs are used.

use anyhow::{Context, Result};
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use tempfile::TempDir;

/// Initializes a real, valid Git repository on disk inside a temporary directory.
/// Performs an initial commit so that `HEAD` is a valid symbolic reference.
pub fn create_test_git_repo() -> Result<TempDir> {
    let dir = TempDir::new().context("Failed to allocate temporary directory for git repo")?;
    let path = dir.path();

    // 1. git init
    let init_status = Command::new("git")
        .args(["init", "-b", "main"])
        .current_dir(path)
        .status()
        .context("git init failed")?;
    if !init_status.success() {
        // Fallback for older git without -b
        Command::new("git").arg("init").current_dir(path).status()?;
    }

    // Configure test identity locally so commit works regardless of machine config
    Command::new("git")
        .args(["config", "user.name", "Workstation Tester"])
        .current_dir(path)
        .status()?;
    Command::new("git")
        .args(["config", "user.email", "tester@workstation.local"])
        .current_dir(path)
        .status()?;

    // 2. Initial commit
    fs::write(path.join("README.md"), b"# Test Repository\n")?;
    Command::new("git")
        .args(["add", "README.md"])
        .current_dir(path)
        .status()?;
    Command::new("git")
        .args(["commit", "-m", "Initial commit"])
        .current_dir(path)
        .status()?;

    Ok(dir)
}

/// Creates a real file with explicit octal POSIX permissions.
pub fn create_test_secret_file(
    parent: &Path,
    name: &str,
    mode: u32,
    content: &str,
) -> Result<PathBuf> {
    let file_path = parent.join(name);
    fs::write(&file_path, content)?;

    let mut perms = fs::metadata(&file_path)?.permissions();
    perms.set_mode(mode);
    fs::set_permissions(&file_path, perms)?;

    Ok(file_path)
}

/// Creates an isolated temporary directory structured as a standard user `$HOME`.
pub fn create_test_home() -> Result<TempDir> {
    let dir = TempDir::new()?;
    let path = dir.path();

    fs::create_dir_all(path.join(".local/bin"))?;
    fs::create_dir_all(path.join(".config"))?;
    fs::create_dir_all(path.join(".secrets"))?;
    fs::create_dir_all(path.join(".claude"))?;
    fs::create_dir_all(path.join(".bash_aliases.d"))?;

    Ok(dir)
}
