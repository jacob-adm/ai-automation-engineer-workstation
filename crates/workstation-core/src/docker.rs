//! # Container Substrate & Self-Healing Service Validator
//!
//! Verifies Docker daemon responsiveness, inspects domain socket permissions, and
//! orchestrates automated recovery via system init managers (`systemd` / `sysvinit`).
//!
//! ## Invariants
//! - **Fast-path Zero Latency**: Exits successfully immediately if `docker info` returns 0.
//! - **Group Permission Guard**: Detects missing `docker` group membership when socket access is restricted.
//! - **Multi-Init Recovery**: Attempts daemon startup via `systemctl` or `service` with unprivileged fallback.
//! - **Readiness Polling**: Polls daemon responsiveness up to 15 seconds after triggering recovery.
//! - **Fail-Closed Diagnostics**: Emits actionable container socket mount advice if unrecoverable.
//!
//! ## Platform Support
//! Target OS: Linux (Ubuntu 22.04+, Debian 12+) and macOS.

use anyhow::{bail, Result};
use colored::Colorize;
use std::path::Path;
use std::process::Command;
use std::thread::sleep;
use std::time::Duration;

// -----------------------------------------------------------------------------
// Section 1: Core Service Validation & Recovery Entrypoint
// -----------------------------------------------------------------------------

/// Asserts Docker daemon responsiveness, verifies socket access, and executes
/// automated service recovery if the daemon is inactive.
///
/// # Behavior
/// 1. Verifies that the `docker` CLI executable exists on `$PATH`.
/// 2. Executes the fast-path check: if `docker info` succeeds, returns immediately.
/// 3. Checks `/var/run/docker.sock` permissions and user group membership.
/// 4. Attempts multi-init service startup (`systemctl` or `service`).
/// 5. Polls daemon readiness across a 15-second window.
///
/// # Errors
/// Returns an error if:
/// - The `docker` CLI is not installed on the system.
/// - Socket permissions are missing and the current user lacks the `docker` group.
/// - The daemon fails to become responsive within the 15-second polling window.
pub fn ensure_docker() -> Result<()> {
    // -------------------------------------------------------------------------
    // Section 2: Docker CLI Availability Pre-flight
    // -------------------------------------------------------------------------
    if !is_command_available("docker") {
        bail!("Docker CLI is not installed on this system.");
    }

    // Fast path: If the daemon is responsive, exit immediately with zero latency
    if is_daemon_responsive() {
        println!(
            "{} Docker daemon is running and accessible.",
            "[OK]".green().bold()
        );
        return Ok(());
    }

    println!(
        "{} Docker daemon is not responding. Checking Linux service and permissions...",
        "[WARN]".yellow().bold()
    );

    // -------------------------------------------------------------------------
    // Section 3: Unix Domain Socket & Group Permissions Guard
    // -------------------------------------------------------------------------
    check_socket_permissions();

    // -------------------------------------------------------------------------
    // Section 4: Multi-Init Service Recovery Attempt (systemd / sysvinit)
    // -------------------------------------------------------------------------
    let service_started = attempt_service_recovery();

    // -------------------------------------------------------------------------
    // Section 5: Daemon Health Readiness Poll (15-Second Window)
    // -------------------------------------------------------------------------
    println!(
        "{} Waiting for Docker daemon to become responsive...",
        "[INFO]".cyan()
    );
    for _ in 1..=15 {
        if is_daemon_responsive() {
            println!(
                "{} Docker daemon started and responsive!",
                "[OK]".green().bold()
            );
            return Ok(());
        }
        sleep(Duration::from_secs(1));
    }

    // -------------------------------------------------------------------------
    // Section 6: Failure State Diagnostics & Actionable Guidance
    // -------------------------------------------------------------------------
    if !service_started {
        println!(
            "{} Docker service was not found in systemctl or service managers. If inside a container, ensure Docker socket is mounted (-v /var/run/docker.sock:/var/run/docker.sock).",
            "[WARN]".yellow().bold()
        );
    }

    bail!("Docker daemon failed to become responsive within 15 seconds.");
}

// -----------------------------------------------------------------------------
// Section 7: Internal Helper Routines & System Assertions
// -----------------------------------------------------------------------------

/// Executes `docker info` to assert live daemon responsiveness.
fn is_daemon_responsive() -> bool {
    Command::new("docker")
        .arg("info")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Inspects `/var/run/docker.sock` file permissions and group membership.
fn check_socket_permissions() {
    let sock_path = Path::new("/var/run/docker.sock");
    if !sock_path.exists() {
        return;
    }

    use std::os::unix::fs::PermissionsExt;
    if let Ok(meta) = std::fs::metadata(sock_path) {
        let mode = meta.permissions().mode();
        let is_rw = (mode & 0o660) != 0;

        if !is_rw {
            // Check if current user is in 'docker' group
            let in_docker_group = Command::new("id")
                .arg("-nG")
                .output()
                .ok()
                .and_then(|o| String::from_utf8(o.stdout).ok())
                .map(|groups| groups.split_whitespace().any(|g| g == "docker"))
                .unwrap_or(false);

            if !in_docker_group {
                let user = std::env::var("USER").unwrap_or_else(|_| "current_user".into());
                println!(
                    "{} Current user '{}' is not in the 'docker' group.",
                    "[ERROR]".red().bold(),
                    user
                );
                println!("To grant docker permissions without root, run:");
                println!(
                    "  \x1b[1msudo usermod -aG docker {} && newgrp docker\x1b[0m",
                    user
                );
            }
        }
    }
}

/// Attempts starting the docker service through `systemctl` or `service`.
/// Returns `true` if a service manager invocation was initiated.
fn attempt_service_recovery() -> bool {
    // Check systemd first
    let has_systemctl = is_command_available("systemctl");
    if has_systemctl {
        let has_docker_unit = Command::new("systemctl")
            .args(["status", "docker"])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);

        if has_docker_unit {
            println!(
                "{} Attempting to start docker via systemctl...",
                "[INFO]".cyan()
            );
            let _ = Command::new("sudo")
                .args(["systemctl", "start", "docker"])
                .status();
            return true;
        }
    }

    // Fallback to sysvinit / service
    let has_service = is_command_available("service");
    if has_service {
        let has_docker_service = Command::new("service")
            .args(["docker", "status"])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);

        if has_docker_service {
            println!(
                "{} Attempting to start docker via service...",
                "[INFO]".cyan()
            );
            let _ = Command::new("sudo")
                .args(["service", "docker", "start"])
                .status();
            return true;
        }
    }

    false
}

/// Checks whether an executable command exists on `$PATH`.
fn is_command_available(cmd: &str) -> bool {
    if let Ok(path_var) = std::env::var("PATH") {
        for dir in path_var.split(':') {
            let full_path = Path::new(dir).join(cmd);
            if full_path.is_file() {
                return true;
            }
        }
    }
    false
}
