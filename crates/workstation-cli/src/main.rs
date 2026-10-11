use anyhow::{bail, Result};
use clap::{Parser, Subcommand};
use colored::Colorize;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use workstation_core::{
    ensure_docker, print_system_overview, DoctorEngine, GuardManager, LinkManager, SecretStore,
    WorktreeManager,
};

#[derive(Parser)]
#[command(name = "workstation")]
#[command(author = "AI Automation Workstation Contributors")]
#[command(version = "0.1.0")]
#[command(about = "Unified AI Automation Workstation runtime & execution substrate", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Run diagnostic environment health checks & self-healing assertions
    Doctor {
        /// Automatically remediate broken symlinks, permissions, and drift
        #[arg(short, long)]
        fix: bool,
    },

    /// Run commands with scoped secrets without ambient shell leakage
    SecretRun {
        /// Explicit secret environment file to load
        #[arg(long)]
        env_file: Option<PathBuf>,

        /// Disable ambient .env / .env.local discovery in current directory
        #[arg(long, aliases = ["no-auto-env"])]
        strict: bool,

        /// Target command and arguments to execute
        #[arg(trailing_var_arg = true, required = true)]
        command: Vec<String>,
    },

    /// Manage isolated git worktrees for concurrent AI agent workflows
    Worktree {
        #[command(subcommand)]
        action: WorktreeCommands,
    },

    /// Out-of-band emergency circuit breaker & guard sentinels
    Guard {
        #[command(subcommand)]
        action: GuardCommands,
    },

    /// Display hardware, memory, GPU, disk, and networking overview
    Sysinfo,

    /// Verify Docker daemon responsiveness and attempt automated recovery
    Docker,

    /// Synchronize all declarative dotfile and binary symlinks
    Links {
        /// Target home directory (defaults to $HOME)
        #[arg(long)]
        target: Option<PathBuf>,

        /// Backup directory (defaults to `~/.dotfiles_backup/<timestamp>`)
        #[arg(long)]
        backup_dir: Option<PathBuf>,

        /// Preview actions without modifying the filesystem
        #[arg(short = 'n', long)]
        dry_run: bool,
    },

    /// Generate shell hooks for dynamic initialization
    Hook {
        /// Shell to generate hooks for (bash)
        shell: String,
    },
}

#[derive(Subcommand)]
enum WorktreeCommands {
    /// Create an isolated worktree and branch for an agent task
    New {
        /// Name of the task/branch
        task_name: String,
        /// Base branch or commit (default: HEAD)
        base_branch: Option<String>,
    },
    /// List all active agent worktrees
    List,
    /// Merge an agent branch back into current branch
    Merge {
        /// Name of the task
        task_name: String,
    },
    /// Remove an agent worktree
    Remove {
        /// Name of the task
        task_name: String,
        /// Force removal and branch deletion
        #[arg(short, long)]
        force: bool,
    },
    /// Prune stale worktree metadata
    Clean,
}

#[derive(Subcommand)]
enum GuardCommands {
    /// Engage emergency circuit breaker to halt all agents immediately
    Stop,
    /// Clear circuit breaker to resume agent execution
    Resume,
    /// Check whether the circuit breaker is currently engaged
    Status,
}

fn main() -> Result<()> {
    #[cfg(unix)]
    unsafe {
        nix::libc::signal(nix::libc::SIGPIPE, nix::libc::SIG_DFL);
    }
    // -------------------------------------------------------------------------
    // Multi-Call Binary Dispatch: Inspect argv[0]
    // -------------------------------------------------------------------------
    let raw_arg0 = std::env::args().next().unwrap_or_default();
    let bin_name = Path::new(&raw_arg0)
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default();

    match bin_name.as_str() {
        "secret-run" => return run_secret_run_shim(),
        "doctor" => return run_doctor_shim(),
        "agent-worktree" => return run_worktree_shim(),
        "sysinfo" => {
            print_system_overview();
            return Ok(());
        }
        "ensure-docker" => return ensure_docker(),
        _ => {}
    }

    // Standard CLI execution via clap
    let cli = Cli::parse();
    let dotfiles_root = find_dotfiles_root()?;

    match cli.command {
        Commands::Doctor { fix } => {
            let engine = DoctorEngine::new(dotfiles_root, fix);
            let report = engine.run_all();
            if report.failed > 0 {
                std::process::exit(1);
            }
        }
        Commands::SecretRun {
            env_file,
            strict,
            command,
        } => {
            let env_strict = std::env::var("SECRET_RUN_STRICT")
                .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
                .unwrap_or(false);
            execute_secret_run(env_file.as_deref(), strict || env_strict, &command)?;
        }
        Commands::Worktree { action } => {
            let mgr = WorktreeManager::discover()?;
            match action {
                WorktreeCommands::New {
                    task_name,
                    base_branch,
                } => mgr.new_worktree(&task_name, base_branch.as_deref())?,
                WorktreeCommands::List => mgr.list()?,
                WorktreeCommands::Merge { task_name } => mgr.merge(&task_name)?,
                WorktreeCommands::Remove { task_name, force } => mgr.remove(&task_name, force)?,
                WorktreeCommands::Clean => mgr.clean()?,
            }
        }
        Commands::Guard { action } => {
            let guard = GuardManager::new();
            match action {
                GuardCommands::Stop => guard.stop()?,
                GuardCommands::Resume => guard.resume()?,
                GuardCommands::Status => {
                    let _ = guard.status();
                }
            }
        }
        Commands::Sysinfo => {
            print_system_overview();
        }
        Commands::Docker => {
            ensure_docker()?;
        }
        Commands::Links {
            target,
            backup_dir,
            dry_run,
        } => {
            let mgr = LinkManager::new(dotfiles_root, target, backup_dir, dry_run);
            mgr.sync_all()?;
        }
        Commands::Hook { shell } => {
            if shell == "bash" {
                print_bash_hook();
            } else {
                bail!("Unsupported shell for hook: {}", shell);
            }
        }
    }

    Ok(())
}

fn find_dotfiles_root() -> Result<PathBuf> {
    // 1. Check DOTFILES_ROOT environment variable
    if let Ok(env_root) = std::env::var("DOTFILES_ROOT") {
        return Ok(PathBuf::from(env_root));
    }

    // 2. Discover relative to current exe
    if let Ok(mut exe) = std::env::current_exe() {
        if let Ok(canonical) = exe.canonicalize() {
            exe = canonical;
        }
        // If installed in ~/.local/bin/workstation -> dotfiles might be in ~/.dotfiles or target
        if let Some(parent) = exe.parent() {
            if parent.ends_with("target/debug") || parent.ends_with("target/release") {
                if let Some(ws_root) = parent.parent().and_then(|p| p.parent()) {
                    return Ok(ws_root.to_path_buf());
                }
            }
        }
    }

    // 3. Current working directory fallback
    let cwd = std::env::current_dir()?;
    if cwd.join("config").is_dir() && cwd.join("bin").is_dir() {
        return Ok(cwd);
    }

    // 4. Fallback to standard location
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    let default_loc = PathBuf::from(&home).join(".dotfiles");
    if default_loc.is_dir() {
        return Ok(default_loc);
    }

    Ok(cwd)
}

fn execute_secret_run(env_file: Option<&Path>, strict: bool, command: &[String]) -> Result<()> {
    if command.is_empty() {
        bail!("No command specified for secret-run");
    }

    let mut store = SecretStore::new();
    let resolved = SecretStore::resolve_secret_file(env_file, strict)?;

    if let Some(ref path) = resolved {
        store.load_file(path)?;
    }

    // Prepare command execution
    let mut cmd = Command::new(&command[0]);
    if command.len() > 1 {
        cmd.args(&command[1..]);
    }

    // Inject parsed secrets strictly into child process
    for (k, v) in &store.entries {
        cmd.env(k, &v.0);
    }

    // Replace current process image (zero leak into parent)
    let err = cmd.exec();
    bail!("Failed to execute command '{}': {}", command[0], err);
}

// -----------------------------------------------------------------------------
// Shims for Direct Multi-Call Invocations
// -----------------------------------------------------------------------------

fn run_secret_run_shim() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut env_file = None;
    let mut strict = std::env::var("SECRET_RUN_STRICT")
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);
    let mut cmd_start_idx = 0;

    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--env-file" => {
                if i + 1 < args.len() {
                    env_file = Some(PathBuf::from(&args[i + 1]));
                    i += 2;
                } else {
                    bail!("--env-file requires a path argument");
                }
            }
            "--strict" | "--no-auto-env" => {
                strict = true;
                i += 1;
            }
            "--" => {
                cmd_start_idx = i + 1;
                break;
            }
            _ => {
                cmd_start_idx = i;
                break;
            }
        }
    }

    if cmd_start_idx >= args.len() {
        println!(
            "{}",
            "secret-run - Run commands with scoped secrets without ambient shell leakage".bold()
        );
        println!("\nUsage: secret-run [--env-file <file>] [--strict] -- <command> [args...]");
        std::process::exit(1);
    }

    let command = &args[cmd_start_idx..];
    execute_secret_run(env_file.as_deref(), strict, command)
}

fn run_doctor_shim() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let fix = args.iter().any(|a| a == "--fix" || a == "-f");
    let dotfiles_root = find_dotfiles_root()?;
    let engine = DoctorEngine::new(dotfiles_root, fix);
    let report = engine.run_all();
    if report.failed > 0 {
        std::process::exit(1);
    }
    Ok(())
}

fn run_worktree_shim() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() {
        println!(
            "{}",
            "agent-worktree - Manage isolated git worktrees for concurrent AI agent workflows"
                .bold()
        );
        println!("\nUsage:\n  agent-worktree new <task-name> [base-branch]\n  agent-worktree list\n  agent-worktree merge <task-name>\n  agent-worktree remove <task-name> [--force]\n  agent-worktree clean");
        std::process::exit(0);
    }

    let mgr = WorktreeManager::discover()?;
    match args[0].as_str() {
        "new" => {
            if args.len() < 2 {
                bail!("Task name required. Usage: agent-worktree new <task-name> [base-branch]");
            }
            let base = args.get(2).map(|s| s.as_str());
            mgr.new_worktree(&args[1], base)?;
        }
        "list" => mgr.list()?,
        "merge" => {
            if args.len() < 2 {
                bail!("Task name required. Usage: agent-worktree merge <task-name>");
            }
            mgr.merge(&args[1])?;
        }
        "remove" => {
            if args.len() < 2 {
                bail!("Task name required. Usage: agent-worktree remove <task-name> [--force]");
            }
            let force = args.iter().any(|a| a == "--force" || a == "-f");
            mgr.remove(&args[1], force)?;
        }
        "clean" => mgr.clean()?,
        _ => bail!(
            "Unknown subcommand: {}. Run agent-worktree for usage.",
            args[0]
        ),
    }
    Ok(())
}

fn print_bash_hook() {
    println!(
        r#"# AI Automation Workstation Shell Integration
alias doctor="workstation doctor"
alias secret-run="workstation secret-run"
alias agent-worktree="workstation worktree"
alias sysinfo="workstation sysinfo"
alias ensure-docker="workstation docker"
alias agent-stop="workstation guard stop"
alias agent-resume="workstation guard resume"
"#
    );
}
