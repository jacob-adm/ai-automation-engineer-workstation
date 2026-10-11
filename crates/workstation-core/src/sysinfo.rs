use colored::Colorize;
use std::process::Command;
use sysinfo::{Disks, System};

pub fn print_system_overview() {
    println!(
        "{}",
        "====================================================="
            .cyan()
            .bold()
    );
    println!(
        "{}",
        "                 SYSTEM OVERVIEW                     "
            .cyan()
            .bold()
    );
    println!(
        "{}",
        "====================================================="
            .cyan()
            .bold()
    );

    let mut sys = System::new_all();
    sys.refresh_all();

    let os_name = System::name().unwrap_or_else(|| "Unknown OS".into());
    let os_version = System::os_version().unwrap_or_default();
    let kernel_version = System::kernel_version().unwrap_or_default();
    let host_name = System::host_name().unwrap_or_default();
    let uptime_sec = System::uptime();
    let hours = uptime_sec / 3600;
    let mins = (uptime_sec % 3600) / 60;

    let user = std::env::var("USER").unwrap_or_else(|_| "unknown".into());
    let shell = std::env::var("SHELL").unwrap_or_else(|_| "unknown".into());

    println!("{:<14} {} {}", "OS:".bold(), os_name, os_version);
    println!("{:<14} {}", "Kernel:".bold(), kernel_version);
    println!("{:<14} {} hours, {} minutes", "Uptime:".bold(), hours, mins);
    println!("{:<14} {}", "Host:".bold(), host_name);
    println!("{:<14} {}", "User:".bold(), user);
    println!("{:<14} {}", "Shell:".bold(), shell);

    println!("\n{}", "--- Resources ---".yellow().bold());

    let total_mem = sys.total_memory() as f64 / (1024.0 * 1024.0 * 1024.0);
    let used_mem = sys.used_memory() as f64 / (1024.0 * 1024.0 * 1024.0);
    println!(
        "{:<14} {:.1} GiB / {:.1} GiB used",
        "Memory:".bold(),
        used_mem,
        total_mem
    );

    let disks = Disks::new_with_refreshed_list();
    if let Some(root_disk) = disks.iter().find(|d| d.mount_point().to_str() == Some("/")) {
        let total_disk = root_disk.total_space() as f64 / (1024.0 * 1024.0 * 1024.0);
        let avail_disk = root_disk.available_space() as f64 / (1024.0 * 1024.0 * 1024.0);
        let used_disk = total_disk - avail_disk;
        let pct = if total_disk > 0.0 {
            (used_disk / total_disk) * 100.0
        } else {
            0.0
        };
        println!(
            "{:<14} {:.1} GiB / {:.1} GiB ({:.0}% used)",
            "Disk (/):".bold(),
            used_disk,
            total_disk,
            pct
        );
    }

    // GPU check
    let gpu_info = Command::new("nvidia-smi")
        .args(["--query-gpu=name,memory.total", "--format=csv,noheader"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.lines().next().unwrap_or_default().to_string());

    if let Some(gpu) = gpu_info {
        if !gpu.is_empty() {
            println!("{:<14} {}", "GPU:".bold(), gpu);
        }
    }

    println!();
}
