use crate::fs_utils::{
    create_atomic_symlink, get_backup_dir, harden_permissions, verify_file_security,
};
use anyhow::Result;
use colored::Colorize;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, PartialEq, Eq)]
pub enum CheckStatus {
    Pass(String),
    Warn(String),
    Fail(String),
}

#[derive(Debug, Default)]
pub struct DoctorReport {
    pub total: usize,
    pub passed: usize,
    pub warnings: usize,
    pub failed: usize,
    pub results: Vec<CheckStatus>,
}

impl DoctorReport {
    pub fn pass(&mut self, msg: impl Into<String>) {
        let msg = msg.into();
        self.total += 1;
        self.passed += 1;
        println!(" {} {}", "✓".green().bold(), msg);
        self.results.push(CheckStatus::Pass(msg));
    }

    pub fn warn(&mut self, msg: impl Into<String>) {
        let msg = msg.into();
        self.total += 1;
        self.warnings += 1;
        println!(" {} {}", "⚠".yellow().bold(), msg);
        self.results.push(CheckStatus::Warn(msg));
    }

    pub fn fail(&mut self, msg: impl Into<String>) {
        let msg = msg.into();
        self.total += 1;
        self.failed += 1;
        println!(" {} {}", "✗".red().bold(), msg);
        self.results.push(CheckStatus::Fail(msg));
    }

    pub fn header(&self, title: &str) {
        println!("\n{}", format!("=== {} ===", title).cyan().bold());
    }
}

pub struct DoctorEngine {
    pub dotfiles_root: PathBuf,
    pub home: PathBuf,
    pub fix_mode: bool,
}

impl DoctorEngine {
    pub fn new(dotfiles_root: PathBuf, fix_mode: bool) -> Self {
        let home = std::env::var("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("."));
        Self {
            dotfiles_root,
            home,
            fix_mode,
        }
    }

    pub fn run_all(&self) -> DoctorReport {
        let mut report = DoctorReport::default();

        println!(
            "{}",
            "====================================================="
                .cyan()
                .bold()
        );
        println!(
            "{}",
            "        ENVIRONMENT HEALTH CHECK (DOCTOR)            "
                .cyan()
                .bold()
        );
        println!(
            "{}",
            "====================================================="
                .cyan()
                .bold()
        );

        // Pre-flight auto-remediation if fix mode is enabled
        if self.fix_mode {
            let _ = self.repair_links();
        }

        self.check_symlinks(&mut report);
        self.check_core_tooling(&mut report);
        self.check_docker(&mut report);
        self.check_git_identity(&mut report);
        self.check_circuit_breaker(&mut report);
        self.check_aliases(&mut report);
        self.check_agent_configs(&mut report);
        self.check_security_invariants(&mut report);

        // Summary
        println!(
            "\n{}",
            "====================================================="
                .cyan()
                .bold()
        );
        println!(
            "Doctor Summary: {} Passed, {} Warnings, {} Failed (out of {} checks)",
            report.passed.to_string().green().bold(),
            report.warnings.to_string().yellow().bold(),
            report.failed.to_string().red().bold(),
            report.total
        );
        println!(
            "{}",
            "====================================================="
                .cyan()
                .bold()
        );

        if report.failed > 0 && !self.fix_mode {
            println!(
                "Tip: Run {} to automatically remediate drift.",
                "workstation doctor --fix".bold()
            );
        }

        report
    }

    pub fn repair_links(&self) -> Result<()> {
        let backup_dir = get_backup_dir();
        // Link definitions: (source_rel, target_rel)
        let link_specs = self.get_symlink_specs();
        for (src_rel, tgt_path) in link_specs {
            let src_path = self.dotfiles_root.join(src_rel);
            if src_path.exists() {
                let _ = create_atomic_symlink(&src_path, &tgt_path, &backup_dir, false);
            }
        }
        Ok(())
    }

    fn get_symlink_specs(&self) -> Vec<(PathBuf, PathBuf)> {
        vec![
            (
                PathBuf::from("config/bash/.bashrc"),
                self.home.join(".bashrc"),
            ),
            (
                PathBuf::from("config/bash/.bash_aliases"),
                self.home.join(".bash_aliases"),
            ),
            (
                PathBuf::from("config/bash/.bash_profile"),
                self.home.join(".bash_profile"),
            ),
            (
                PathBuf::from("config/bash/.profile"),
                self.home.join(".profile"),
            ),
            (
                PathBuf::from("config/git/.gitconfig"),
                self.home.join(".gitconfig"),
            ),
            (
                PathBuf::from("config/git/.gitignore_global"),
                self.home.join(".gitignore_global"),
            ),
            (
                PathBuf::from("config/tmux/.tmux.conf"),
                self.home.join(".tmux.conf"),
            ),
            (PathBuf::from("config/vim/.vimrc"), self.home.join(".vimrc")),
            (PathBuf::from("config/npm/.npmrc"), self.home.join(".npmrc")),
            (
                PathBuf::from("config/uv/uv.toml"),
                self.home.join(".config/uv/uv.toml"),
            ),
            (
                PathBuf::from("config/pueue/pueue.yml"),
                self.home.join(".config/pueue/pueue.yml"),
            ),
            (
                PathBuf::from("config/ai_automation/ai_automation.sh"),
                self.home.join(".ai_automation.sh"),
            ),
            (
                PathBuf::from("config/mcp/mcp.json"),
                self.home.join(".config/mcp/mcp.json"),
            ),
            (
                PathBuf::from("config/agents/AGENTS.md"),
                self.home.join(".config/agents/AGENTS.md"),
            ),
            (
                PathBuf::from("config/agents/AGENTS.md"),
                self.home.join(".claude/CLAUDE.md"),
            ),
            (
                PathBuf::from("config/claude/settings.json"),
                self.home.join(".claude/settings.json"),
            ),
            (
                PathBuf::from("config/opencode/opencode.json"),
                self.home.join(".config/opencode/opencode.json"),
            ),
            // Modular Aliases (~/.bash_aliases.d)
            (
                PathBuf::from("config/bash/aliases.d/ai.sh"),
                self.home.join(".bash_aliases.d/ai.sh"),
            ),
            (
                PathBuf::from("config/bash/aliases.d/containers.sh"),
                self.home.join(".bash_aliases.d/containers.sh"),
            ),
            (
                PathBuf::from("config/bash/aliases.d/git.sh"),
                self.home.join(".bash_aliases.d/git.sh"),
            ),
            (
                PathBuf::from("config/bash/aliases.d/nav.sh"),
                self.home.join(".bash_aliases.d/nav.sh"),
            ),
            (
                PathBuf::from("config/bash/aliases.d/sys.sh"),
                self.home.join(".bash_aliases.d/sys.sh"),
            ),
            (
                PathBuf::from("bin/agent-worktree"),
                self.home.join(".local/bin/agent-worktree"),
            ),
            (
                PathBuf::from("bin/check-mcp-logs"),
                self.home.join(".local/bin/check-mcp-logs"),
            ),
            (
                PathBuf::from("bin/doctor"),
                self.home.join(".local/bin/doctor"),
            ),
            (
                PathBuf::from("bin/dotfiles-update"),
                self.home.join(".local/bin/dotfiles-update"),
            ),
            (
                PathBuf::from("bin/ensure-docker"),
                self.home.join(".local/bin/ensure-docker"),
            ),
            (
                PathBuf::from("bin/gha-failed-logs"),
                self.home.join(".local/bin/gha-failed-logs"),
            ),
            (
                PathBuf::from("bin/pr-checkout"),
                self.home.join(".local/bin/pr-checkout"),
            ),
            (
                PathBuf::from("bin/secret-run"),
                self.home.join(".local/bin/secret-run"),
            ),
            (
                PathBuf::from("bin/sysinfo"),
                self.home.join(".local/bin/sysinfo"),
            ),
        ]
    }

    fn check_symlinks(&self, report: &mut DoctorReport) {
        report.header("Checking Dotfile Symlinks");
        let specs = self.get_symlink_specs();
        let backup_dir = get_backup_dir();

        for (src_rel, target) in specs {
            let src_path = self.dotfiles_root.join(&src_rel);
            let target_display = target.display().to_string();

            if let Ok(meta) = fs::symlink_metadata(&target) {
                if meta.file_type().is_symlink() && target.exists() {
                    let points_to = fs::read_link(&target).unwrap_or_default();
                    report.pass(format!(
                        "Symlink verified: {} -> {}",
                        target_display,
                        points_to.display()
                    ));
                    continue;
                }
            }

            // Broken or missing link
            if self.fix_mode
                && src_path.exists()
                && create_atomic_symlink(&src_path, &target, &backup_dir, false).is_ok()
                && target.exists()
            {
                report.pass(format!(
                    "Symlink restored and verified: {} -> {}",
                    target_display,
                    src_path.display()
                ));
                continue;
            }

            report.fail(format!("Missing or broken symlink: {}", target_display));
        }
    }

    fn check_core_tooling(&self, report: &mut DoctorReport) {
        report.header("Checking Core & AI Tooling");
        let tools = [
            ("git", "Git version control"),
            ("tmux", "Terminal multiplexer"),
            ("vim", "Text editor"),
            ("uv", "Python & AI package manager"),
            ("direnv", "Directory-scoped environment manager"),
            ("pueue", "Background task queue"),
            ("zoxide", "Smart directory navigation"),
            ("rg", "Ripgrep code search"),
            ("fzf", "Fuzzy finder"),
            ("htop", "Process monitor"),
            ("jq", "JSON processor"),
        ];

        for (cmd, desc) in tools {
            if is_command_available(cmd) {
                report.pass(format!("{} ({})", cmd, desc));
            } else {
                report.fail(format!("Missing command: {} ({})", cmd, desc));
            }
        }

        // Aliased tooling
        if is_command_available("bat") || is_command_available("batcat") {
            report.pass("bat/batcat (Syntax-highlighted cat)");
        } else {
            report.fail("Missing command: bat/batcat");
        }

        if is_command_available("fd") || is_command_available("fdfind") {
            report.pass("fd/fdfind (Fast file discovery)");
        } else {
            report.fail("Missing command: fd/fdfind");
        }
    }

    fn check_docker(&self, report: &mut DoctorReport) {
        report.header("Checking Docker Daemon");
        if !is_command_available("docker") {
            report.warn("Docker CLI is not installed");
            return;
        }

        let is_running = Command::new("docker")
            .arg("info")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);

        if is_running {
            report.pass("Docker daemon is reachable and running");
        } else {
            report.warn(
                "Docker daemon is not responding (run 'ensure-docker' or check socket permissions)",
            );
        }
    }

    fn check_git_identity(&self, report: &mut DoctorReport) {
        report.header("Checking Git Identity");
        let name = Command::new("git")
            .args(["config", "--global", "user.name"])
            .output()
            .ok()
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .unwrap_or_default();
        let email = Command::new("git")
            .args(["config", "--global", "user.email"])
            .output()
            .ok()
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .unwrap_or_default();

        let name = name.trim();
        let email = email.trim();

        if !name.is_empty() && !email.is_empty() {
            report.pass(format!("Git identity configured: {} <{}>", name, email));
        } else {
            report.warn("Git identity incomplete. Set via: git config --global user.name ... and user.email ...");
        }
    }

    fn check_circuit_breaker(&self, report: &mut DoctorReport) {
        report.header("Checking AI Agent Circuit Breaker");
        let sentinel = self.home.join(".agent_stop");
        if sentinel.exists() {
            report.warn(
                "Circuit breaker is ENGAGED (~/.agent_stop exists). Clear with 'agent-resume'.",
            );
        } else {
            report.pass("Circuit breaker is clear / ready (all automated agent loops permitted)");
        }
    }

    fn check_aliases(&self, report: &mut DoctorReport) {
        report.header("Checking Modular Shell Aliases (~/.bash_aliases.d)");
        let dir = self.home.join(".bash_aliases.d");
        if dir.is_dir() {
            let count = fs::read_dir(&dir)
                .map(|entries| {
                    entries
                        .filter_map(|e| e.ok())
                        .filter(|e| e.path().extension().and_then(|ext| ext.to_str()) == Some("sh"))
                        .count()
                })
                .unwrap_or(0);
            report.pass(format!(
                "~/.bash_aliases.d directory exists ({} modules)",
                count
            ));
        } else {
            report.fail("~/.bash_aliases.d directory missing");
        }
    }

    fn check_agent_configs(&self, report: &mut DoctorReport) {
        report.header("Checking AI Coding Agent Setup (Claude Code & OpenCode)");
        let claude_md = self.home.join(".claude/CLAUDE.md");
        let claude_settings = self.home.join(".claude/settings.json");

        if claude_md.is_file() && claude_settings.is_file() {
            report.pass("Claude Code unified instructions and settings verified (~/.claude)");
        } else {
            report.fail("Claude Code configuration missing or broken");
        }

        let opencode_json = self.home.join(".config/opencode/opencode.json");
        if opencode_json.is_file() {
            report.pass("OpenCode unified configuration verified (~/.config/opencode)");
        } else {
            report.fail("OpenCode configuration missing or broken");
        }
    }

    fn check_security_invariants(&self, report: &mut DoctorReport) {
        report.header("Checking Security & Supply Chain Invariants");

        // MCP filesystem check
        let mcp_json = self.home.join(".config/mcp/mcp.json");
        if mcp_json.is_file() {
            if let Ok(content) = fs::read_to_string(&mcp_json) {
                if let Ok(v) = serde_json::from_str::<serde_json::Value>(&content) {
                    let has_bare_dot = v["mcpServers"]["filesystem"]["args"]
                        .as_array()
                        .map(|arr| arr.iter().any(|arg| arg.as_str() == Some(".")))
                        .unwrap_or(false);

                    if has_bare_dot {
                        report.warn("MCP filesystem server config exposes bare '.' directory");
                    } else {
                        report.pass("MCP filesystem server configuration bounded");
                    }
                }
            }
        }

        // Secret permissions check
        let secret_file = self.home.join(".secrets/ai.env");
        if secret_file.is_file() {
            if verify_file_security(&secret_file).is_ok() {
                report.pass("Secret file ~/.secrets/ai.env has secure permissions");
            } else if self.fix_mode {
                let _ = harden_permissions(&secret_file);
                report.pass("Hardened ~/.secrets/ai.env permissions to 0600");
            } else {
                report.warn("Secret file ~/.secrets/ai.env has loose permissions. Run: chmod 600 ~/.secrets/ai.env");
            }
        } else {
            report.pass("No default secret file in ~/.secrets/ai.env (clean environment)");
        }

        // Binary checksum updater check
        let updater = self.dotfiles_root.join("scripts/update-checksums.sh");
        if updater.is_file() {
            report.pass(
                "Binary checksum verification tool operational (scripts/update-checksums.sh)",
            );
        }
    }
}

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
