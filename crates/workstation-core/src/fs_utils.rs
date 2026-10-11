use anyhow::{bail, Context, Result};
use chrono::Local;
use std::fs;
use std::os::unix::fs::{symlink, MetadataExt, PermissionsExt};
use std::path::{Path, PathBuf};

/// Verifies whether a given file has secure permissions (0600 or 0400)
/// and is owned by the current effective user ID.
pub fn verify_file_security(path: &Path) -> Result<()> {
    if !path.exists() {
        bail!("File does not exist: {}", path.display());
    }

    let meta = fs::metadata(path)
        .with_context(|| format!("Failed to read metadata for {}", path.display()))?;

    let mode = meta.permissions().mode() & 0o777;
    if mode != 0o600 && mode != 0o400 {
        bail!(
            "Secret file '{}' has insecure permissions ({:04o}). Required: 0600 or 0400. Remediate with: chmod 600 '{}'",
            path.display(),
            mode,
            path.display()
        );
    }

    let owner_uid = meta.uid();
    let current_euid = nix::unistd::geteuid().as_raw();
    if owner_uid != current_euid {
        bail!(
            "Secret file '{}' is owned by UID {}, not current user UID {}. Refusing to execute.",
            path.display(),
            owner_uid,
            current_euid
        );
    }

    Ok(())
}

/// Hardens file permissions to 0600 (owner read/write only).
pub fn harden_permissions(path: &Path) -> Result<()> {
    let mut perms = fs::metadata(path)?.permissions();
    perms.set_mode(0o600);
    fs::set_permissions(path, perms)?;
    Ok(())
}

/// Creates a timestamped backup directory under `~/.dotfiles_backup/<timestamp>/`.
pub fn get_backup_dir() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    let timestamp = Local::now().format("%Y%m%d_%H%M%S").to_string();
    PathBuf::from(home).join(".dotfiles_backup").join(timestamp)
}

/// Backs up a destination file if it is a regular non-symlink file before creating a symlink.
pub fn backup_if_needed(target: &Path, backup_dir: &Path) -> Result<Option<PathBuf>> {
    let symlink_meta = match fs::symlink_metadata(target) {
        Ok(m) => m,
        Err(_) => return Ok(None),
    };

    // If it's already a symlink, no need to back it up (will be safely replaced)
    if symlink_meta.file_type().is_symlink() {
        return Ok(None);
    }

    let file_name = target.file_name().unwrap_or_default();
    let backup_path = backup_dir.join(file_name);

    if let Some(parent) = backup_path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::rename(target, &backup_path)?;
    Ok(Some(backup_path))
}

/// Creates an atomic symlink from `source` to `target`.
/// If `dry_run` is true, performs checks without mutating the filesystem.
pub fn create_atomic_symlink(
    source: &Path,
    target: &Path,
    backup_dir: &Path,
    dry_run: bool,
) -> Result<bool> {
    if !source.exists() {
        bail!("Source file does not exist: {}", source.display());
    }

    // Check if target is already a symlink pointing to source
    if let Ok(meta) = fs::symlink_metadata(target) {
        if meta.file_type().is_symlink() {
            if let Ok(link_target) = fs::read_link(target) {
                if link_target == source {
                    return Ok(false); // Already correct
                }
            }
            if !dry_run {
                fs::remove_file(target)?;
            }
        } else {
            // Target is a real file/dir
            if !dry_run {
                backup_if_needed(target, backup_dir)?;
            }
        }
    }

    if dry_run {
        return Ok(true);
    }

    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)?;
    }

    symlink(source, target).with_context(|| {
        format!(
            "Failed to symlink {} -> {}",
            target.display(),
            source.display()
        )
    })?;

    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn test_file_security_permissions() {
        let file = NamedTempFile::new().unwrap();
        let path = file.path();

        // Set to 0644 (insecure)
        let mut perms = fs::metadata(path).unwrap().permissions();
        perms.set_mode(0o644);
        fs::set_permissions(path, perms).unwrap();
        assert!(verify_file_security(path).is_err());

        // Set to 0600 (secure)
        harden_permissions(path).unwrap();
        assert!(verify_file_security(path).is_ok());

        // Set to 0400 (secure read-only)
        let mut perms = fs::metadata(path).unwrap().permissions();
        perms.set_mode(0o400);
        fs::set_permissions(path, perms).unwrap();
        assert!(verify_file_security(path).is_ok());
    }
}
