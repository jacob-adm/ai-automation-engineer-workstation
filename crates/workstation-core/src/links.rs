use crate::fs_utils::{create_atomic_symlink, get_backup_dir};
use anyhow::Result;
use colored::Colorize;
use std::path::PathBuf;

pub struct LinkManager {
    pub dotfiles_root: PathBuf,
    pub target_dir: PathBuf,
    pub backup_dir: PathBuf,
    pub dry_run: bool,
}

impl LinkManager {
    pub fn new(
        dotfiles_root: PathBuf,
        target_dir: Option<PathBuf>,
        backup_dir: Option<PathBuf>,
        dry_run: bool,
    ) -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
        let target = target_dir.unwrap_or_else(|| PathBuf::from(&home));
        let backup = backup_dir.unwrap_or_else(get_backup_dir);
        Self {
            dotfiles_root,
            target_dir: target,
            backup_dir: backup,
            dry_run,
        }
    }

    pub fn sync_all(&self) -> Result<()> {
        println!(
            "{}",
            "====================================================="
                .cyan()
                .bold()
        );
        println!(
            "{}",
            "       DECLARATIVE SYMLINK SYNCHRONIZATION           "
                .cyan()
                .bold()
        );
        println!(
            "{}",
            "====================================================="
                .cyan()
                .bold()
        );

        if self.dry_run {
            println!(
                "{}",
                "DRY RUN MODE: No filesystem mutations will be performed."
                    .yellow()
                    .bold()
            );
        }

        let specs = self.get_all_specs();
        let mut created = 0;
        let mut verified = 0;

        for (src_rel, tgt_rel) in specs {
            let src_path = self.dotfiles_root.join(&src_rel);
            let tgt_path = self.target_dir.join(&tgt_rel);

            if !src_path.exists() {
                continue;
            }

            match create_atomic_symlink(&src_path, &tgt_path, &self.backup_dir, self.dry_run) {
                Ok(true) => {
                    if self.dry_run {
                        println!(
                            " [DRY-RUN] Would link: {} -> {}",
                            tgt_path.display(),
                            src_path.display()
                        );
                    } else {
                        println!(
                            " {} Linked: {} -> {}",
                            "[OK]".green(),
                            tgt_path.display(),
                            src_path.display()
                        );
                    }
                    created += 1;
                }
                Ok(false) => {
                    println!(
                        " Already linked: {} -> {}",
                        tgt_path.display(),
                        src_path.display()
                    );
                    verified += 1;
                }
                Err(e) => {
                    println!(" {} Failed {}: {}", "[ERR]".red(), tgt_path.display(), e);
                }
            }
        }

        println!(
            "\nSummary: {} new links created, {} pre-existing verified.",
            created, verified
        );
        Ok(())
    }

    fn get_all_specs(&self) -> Vec<(PathBuf, PathBuf)> {
        vec![
            (
                PathBuf::from("config/bash/.bashrc"),
                PathBuf::from(".bashrc"),
            ),
            (
                PathBuf::from("config/bash/.bash_aliases"),
                PathBuf::from(".bash_aliases"),
            ),
            (
                PathBuf::from("config/bash/.bash_profile"),
                PathBuf::from(".bash_profile"),
            ),
            (
                PathBuf::from("config/bash/.profile"),
                PathBuf::from(".profile"),
            ),
            (
                PathBuf::from("config/git/.gitconfig"),
                PathBuf::from(".gitconfig"),
            ),
            (
                PathBuf::from("config/git/.gitignore_global"),
                PathBuf::from(".gitignore_global"),
            ),
            (
                PathBuf::from("config/tmux/.tmux.conf"),
                PathBuf::from(".tmux.conf"),
            ),
            (PathBuf::from("config/vim/.vimrc"), PathBuf::from(".vimrc")),
            (PathBuf::from("config/npm/.npmrc"), PathBuf::from(".npmrc")),
            (
                PathBuf::from("config/uv/uv.toml"),
                PathBuf::from(".config/uv/uv.toml"),
            ),
            (
                PathBuf::from("config/pueue/pueue.yml"),
                PathBuf::from(".config/pueue/pueue.yml"),
            ),
            (
                PathBuf::from("config/ai_automation/ai_automation.sh"),
                PathBuf::from(".ai_automation.sh"),
            ),
            (
                PathBuf::from("config/mcp/mcp.json"),
                PathBuf::from(".config/mcp/mcp.json"),
            ),
            (
                PathBuf::from("config/agents/AGENTS.md"),
                PathBuf::from(".config/agents/AGENTS.md"),
            ),
            (
                PathBuf::from("config/agents/AGENTS.md"),
                PathBuf::from(".claude/CLAUDE.md"),
            ),
            (
                PathBuf::from("config/claude/settings.json"),
                PathBuf::from(".claude/settings.json"),
            ),
            (
                PathBuf::from("config/opencode/opencode.json"),
                PathBuf::from(".config/opencode/opencode.json"),
            ),
            // Modular Aliases (~/.bash_aliases.d)
            (
                PathBuf::from("config/bash/aliases.d/ai.sh"),
                PathBuf::from(".bash_aliases.d/ai.sh"),
            ),
            (
                PathBuf::from("config/bash/aliases.d/containers.sh"),
                PathBuf::from(".bash_aliases.d/containers.sh"),
            ),
            (
                PathBuf::from("config/bash/aliases.d/git.sh"),
                PathBuf::from(".bash_aliases.d/git.sh"),
            ),
            (
                PathBuf::from("config/bash/aliases.d/nav.sh"),
                PathBuf::from(".bash_aliases.d/nav.sh"),
            ),
            (
                PathBuf::from("config/bash/aliases.d/sys.sh"),
                PathBuf::from(".bash_aliases.d/sys.sh"),
            ),
            // CLI binaries
            (
                PathBuf::from("bin/agent-worktree"),
                PathBuf::from(".local/bin/agent-worktree"),
            ),
            (
                PathBuf::from("bin/check-mcp-logs"),
                PathBuf::from(".local/bin/check-mcp-logs"),
            ),
            (
                PathBuf::from("bin/doctor"),
                PathBuf::from(".local/bin/doctor"),
            ),
            (
                PathBuf::from("bin/dotfiles-update"),
                PathBuf::from(".local/bin/dotfiles-update"),
            ),
            (
                PathBuf::from("bin/ensure-docker"),
                PathBuf::from(".local/bin/ensure-docker"),
            ),
            (
                PathBuf::from("bin/gha-failed-logs"),
                PathBuf::from(".local/bin/gha-failed-logs"),
            ),
            (
                PathBuf::from("bin/pr-checkout"),
                PathBuf::from(".local/bin/pr-checkout"),
            ),
            (
                PathBuf::from("bin/secret-run"),
                PathBuf::from(".local/bin/secret-run"),
            ),
            (
                PathBuf::from("bin/sysinfo"),
                PathBuf::from(".local/bin/sysinfo"),
            ),
        ]
    }
}
