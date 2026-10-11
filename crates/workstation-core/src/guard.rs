use crate::fs_utils::verify_file_security;
use anyhow::{bail, Context, Result};
use colored::Colorize;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::PathBuf;

pub struct GuardManager {
    sentinel_path: PathBuf,
}

impl Default for GuardManager {
    fn default() -> Self {
        Self::new()
    }
}

impl GuardManager {
    pub fn new() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
        Self {
            sentinel_path: PathBuf::from(home).join(".agent_stop"),
        }
    }

    pub fn stop(&self) -> Result<()> {
        fs::write(&self.sentinel_path, b"STOP\n").with_context(|| {
            format!("Failed to create sentinel {}", self.sentinel_path.display())
        })?;

        let mut perms = fs::metadata(&self.sentinel_path)?.permissions();
        perms.set_mode(0o600);
        fs::set_permissions(&self.sentinel_path, perms)?;

        println!(
            "{} Emergency stop active: {}",
            "[CIRCUIT BREAKER ENGAGED]".red().bold(),
            self.sentinel_path.display()
        );
        println!("All local agent harnesses and automated loops will immediately abort.");
        Ok(())
    }

    pub fn resume(&self) -> Result<()> {
        if !self.sentinel_path.exists() {
            println!("Circuit breaker is not engaged. All systems operational.");
            return Ok(());
        }

        // Verify ownership before removing
        verify_file_security(&self.sentinel_path)?;

        fs::remove_file(&self.sentinel_path).with_context(|| {
            format!("Failed to remove sentinel {}", self.sentinel_path.display())
        })?;

        println!(
            "{} Emergency stop cleared: {}",
            "[CIRCUIT BREAKER CLEARED]".green().bold(),
            self.sentinel_path.display()
        );
        println!("Autonomous agent loops are now permitted to resume execution.");
        Ok(())
    }

    pub fn status(&self) -> bool {
        let engaged = self.sentinel_path.exists();
        if engaged {
            println!(
                "{} Sentinel is present ({})",
                "[HALTED]".red().bold(),
                self.sentinel_path.display()
            );
        } else {
            println!(
                "{} Circuit breaker clear. Agents permitted.",
                "[READY]".green().bold()
            );
        }
        engaged
    }

    pub fn assert_permitted(&self) -> Result<()> {
        if self.sentinel_path.exists() {
            bail!(
                "Agent execution rejected: circuit breaker engaged (~/.agent_stop exists). Clear with 'workstation guard resume'"
            );
        }
        Ok(())
    }
}
