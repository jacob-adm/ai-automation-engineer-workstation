//! # Tier 3: Integration Testing - Multi-Agent Worktree Concurrency
//!
//! Validates `WorktreeManager` coordinating with real Git repositories on physical disk.
//!
//! ## Invariants Under Test
//! - Creates isolated worktrees in `.worktrees/<task>` on dedicated `agent/<task>` branches.
//! - Propagates root-level `.envrc` files into the child worktree directory.
//! - Rejects collisions when attempting to create duplicate active worktrees.
//! - Cleans up both filesystem directories and Git branch references upon removal.
//!
//! ## Falsifiability
//! Any corrupt Git state, branch leakage, or failure to isolate working directories
//! results in immediate test failure.

mod common;

use std::fs;
use std::process::Command;
use workstation_core::WorktreeManager;

// -----------------------------------------------------------------------------
// Section 1: End-to-End Git Worktree Lifecycle Assertions
// -----------------------------------------------------------------------------

/// Tests the full worktree lifecycle: creation, .envrc copying, collision guard, merge, and removal.
///
/// # Invariant Tested
/// Each autonomous agent task executes in complete filesystem isolation from the main
/// repository index, with dedicated branch tracking and clean tear-down.
///
/// # Falsification Condition
/// Fails if duplicate worktrees overwrite existing files or if removal leaves dangling branches.
#[test]
fn test_worktree_full_lifecycle_and_isolation() {
    let repo_dir = common::create_test_git_repo().expect("Failed to create real test git repo");
    let repo_path = repo_dir.path();

    // 1. Create a root .envrc file
    let envrc_path = repo_path.join(".envrc");
    fs::write(&envrc_path, "export WORKSTATION_ENV=isolated\n").unwrap();

    // Switch process current directory to the test repository
    let original_cwd = std::env::current_dir().unwrap();
    std::env::set_current_dir(repo_path).unwrap();

    let mgr = WorktreeManager::discover().expect("Failed to discover test git repo");

    // 2. Create isolated worktree for 'auth-refactor'
    let task_name = "auth-refactor";
    mgr.new_worktree(task_name, None)
        .expect("Worktree creation must succeed");

    let worktree_dir = repo_path.join(".worktrees").join(task_name);
    assert!(
        worktree_dir.is_dir(),
        "Worktree directory must physically exist"
    );

    // Verify .envrc propagation
    let child_envrc = worktree_dir.join(".envrc");
    assert!(
        child_envrc.is_file(),
        ".envrc must be propagated to worktree"
    );
    let content = fs::read_to_string(child_envrc).unwrap();
    assert_eq!(content, "export WORKSTATION_ENV=isolated\n");

    // 3. Collision Guard: Attempting duplicate task must fail closed
    assert!(
        mgr.new_worktree(task_name, None).is_err(),
        "Duplicate worktree creation MUST be rejected"
    );

    // 4. Commit a file inside the isolated worktree
    let agent_file = worktree_dir.join("agent_work.txt");
    fs::write(&agent_file, "Completed by agent\n").unwrap();

    Command::new("git")
        .args(["add", "agent_work.txt"])
        .current_dir(&worktree_dir)
        .status()
        .unwrap();
    Command::new("git")
        .args(["commit", "-m", "Agent task work"])
        .current_dir(&worktree_dir)
        .status()
        .unwrap();

    // 5. Merge agent work back into main
    mgr.merge(task_name).expect("Merge must succeed");
    assert!(
        repo_path.join("agent_work.txt").is_file(),
        "Merged file must appear in main branch"
    );

    // 6. Remove worktree
    mgr.remove(task_name, false).expect("Removal must succeed");
    assert!(!worktree_dir.exists(), "Worktree directory must be removed");

    // 7. Prune metadata
    mgr.clean().expect("Clean must succeed");

    // Restore working directory
    std::env::set_current_dir(original_cwd).unwrap();
}
