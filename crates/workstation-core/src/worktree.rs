use anyhow::{bail, Context, Result};
use colored::Colorize;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

pub struct WorktreeManager {
    repo_root: PathBuf,
}

impl WorktreeManager {
    pub fn discover() -> Result<Self> {
        let output = Command::new("git")
            .args(["rev-parse", "--show-toplevel"])
            .output()
            .context("Failed to run git. Ensure git is installed.")?;

        if !output.status.success() {
            bail!("Not inside a git repository.");
        }

        let root_str = String::from_utf8(output.stdout)?.trim().to_string();
        Ok(Self {
            repo_root: PathBuf::from(root_str),
        })
    }

    pub fn new_worktree(&self, task_name: &str, base_branch: Option<&str>) -> Result<()> {
        let base = base_branch.unwrap_or("HEAD");
        let worktrees_dir = self.repo_root.join(".worktrees");
        let target_dir = worktrees_dir.join(task_name);
        let branch_name = format!("agent/{}", task_name);

        if target_dir.exists() {
            bail!("Worktree path already exists: {}", target_dir.display());
        }

        println!(
            "{} Creating isolated agent worktree for task '{}'...",
            "[INFO]".cyan(),
            task_name
        );

        fs::create_dir_all(&worktrees_dir)?;

        let status = Command::new("git")
            .current_dir(&self.repo_root)
            .args([
                "worktree",
                "add",
                "-b",
                &branch_name,
                target_dir.to_str().unwrap(),
                base,
            ])
            .status()
            .context("Failed to execute git worktree add")?;

        if !status.success() {
            bail!("Failed to create git worktree");
        }

        // Propagate project-level secrets (.envrc) without tracking them
        let root_envrc = self.repo_root.join(".envrc");
        if root_envrc.is_file() {
            let target_envrc = target_dir.join(".envrc");
            fs::copy(&root_envrc, &target_envrc)?;
            let _ = Command::new("direnv")
                .args(["allow", target_dir.to_str().unwrap()])
                .status();
        }

        println!(
            "{} Agent worktree ready at: {}",
            "[OK]".green().bold(),
            target_dir.display()
        );
        println!("  Branch: {}", branch_name.bold());
        println!("  Switch to directory with: cd {}", target_dir.display());

        Ok(())
    }

    pub fn list(&self) -> Result<()> {
        let status = Command::new("git")
            .current_dir(&self.repo_root)
            .args(["worktree", "list"])
            .status()?;

        if !status.success() {
            bail!("Failed to list git worktrees");
        }
        Ok(())
    }

    pub fn merge(&self, task_name: &str) -> Result<()> {
        let branch_name = format!("agent/{}", task_name);
        let target_dir = self.repo_root.join(".worktrees").join(task_name);
        println!(
            "{} Merging branch '{}' into current branch...",
            "[INFO]".cyan(),
            branch_name
        );

        let status = Command::new("git")
            .current_dir(&self.repo_root)
            .args([
                "merge",
                "--no-ff",
                "-m",
                &format!("Merge agent task: {}", task_name),
                &branch_name,
            ])
            .status()?;

        if !status.success() {
            bail!("Git merge failed. Please resolve conflicts manually.");
        }

        println!(
            "{} Merged task '{}' successfully.",
            "[OK]".green().bold(),
            task_name
        );

        // Post-merge cleanup: Dismantle worktree and remove merged agent branch
        if target_dir.is_dir() {
            let target_envrc = target_dir.join(".envrc");
            if target_envrc.is_file() {
                let _ = fs::remove_file(&target_envrc);
            }
            let _ = Command::new("git")
                .current_dir(&self.repo_root)
                .args(["worktree", "remove", target_dir.to_str().unwrap()])
                .status();
            let _ = Command::new("git")
                .current_dir(&self.repo_root)
                .args(["branch", "-d", &branch_name])
                .status();
            println!("{} Cleaned up worktree and branch.", "[OK]".green().bold());
        }

        Ok(())
    }

    pub fn remove(&self, task_name: &str, force: bool) -> Result<()> {
        let target_dir = self.repo_root.join(".worktrees").join(task_name);
        let branch_name = format!("agent/{}", task_name);

        if !target_dir.is_dir() {
            println!(
                "{} Worktree directory does not exist: {}",
                "[WARN]".yellow(),
                target_dir.display()
            );
            let _ = Command::new("git")
                .current_dir(&self.repo_root)
                .args(["worktree", "prune"])
                .status();
            return Ok(());
        }

        println!(
            "{} Removing worktree at {}...",
            "[INFO]".cyan(),
            target_dir.display()
        );

        // Remove uncommitted .envrc created during worktree setup
        let target_envrc = target_dir.join(".envrc");
        if target_envrc.is_file() {
            let _ = fs::remove_file(&target_envrc);
        }

        let mut args = vec!["worktree", "remove"];
        if force {
            args.push("--force");
        }
        args.push(target_dir.to_str().unwrap());

        let status = Command::new("git")
            .current_dir(&self.repo_root)
            .args(&args)
            .status()?;

        if !status.success() {
            bail!("Failed to remove git worktree");
        }

        // Clean up branch
        let mut branch_args = vec!["branch"];
        if force {
            branch_args.push("-D");
        } else {
            branch_args.push("-d");
        }
        branch_args.push(&branch_name);

        let _ = Command::new("git")
            .current_dir(&self.repo_root)
            .args(&branch_args)
            .status();

        println!(
            "{} Removed agent worktree '{}'.",
            "[OK]".green().bold(),
            task_name
        );
        Ok(())
    }

    pub fn clean(&self) -> Result<()> {
        println!("{} Pruning stale worktree metadata...", "[INFO]".cyan());
        let status = Command::new("git")
            .current_dir(&self.repo_root)
            .args(["worktree", "prune"])
            .status()?;

        if !status.success() {
            bail!("Failed to prune git worktrees");
        }
        println!("{} Worktree pruning complete.", "[OK]".green().bold());
        Ok(())
    }
}
