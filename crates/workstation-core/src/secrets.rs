use crate::fs_utils::verify_file_security;
use anyhow::{bail, Context, Result};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use zeroize::{Zeroize, ZeroizeOnDrop};

#[derive(Debug, Clone, Zeroize, ZeroizeOnDrop)]
pub struct SecretValue(pub String);

#[derive(Debug, Default)]
pub struct SecretStore {
    pub entries: HashMap<String, SecretValue>,
}

impl SecretStore {
    pub fn new() -> Self {
        Self {
            entries: HashMap::new(),
        }
    }

    /// Resolves the candidate secret file path based on strict mode and user input.
    pub fn resolve_secret_file(
        explicit_file: Option<&Path>,
        strict: bool,
    ) -> Result<Option<PathBuf>> {
        if let Some(path) = explicit_file {
            if !path.exists() {
                bail!("Specified secret file not found: '{}'", path.display());
            }
            return Ok(Some(path.to_path_buf()));
        }

        // Automatic discovery hierarchy
        if !strict {
            let local_env_local = Path::new(".env.local");
            if local_env_local.is_file() {
                return Ok(Some(local_env_local.to_path_buf()));
            }

            let local_env = Path::new(".env");
            if local_env.is_file() {
                return Ok(Some(local_env.to_path_buf()));
            }
        }

        if let Ok(home) = std::env::var("HOME") {
            let home_secret = PathBuf::from(&home).join(".secrets/ai.env");
            if home_secret.is_file() {
                return Ok(Some(home_secret));
            }

            let dotfiles_local = PathBuf::from(&home).join(".dotfiles.local");
            if dotfiles_local.is_file() {
                return Ok(Some(dotfiles_local));
            }
        }

        Ok(None)
    }

    /// Loads and parses secrets from a file with strict security invariants.
    pub fn load_file(&mut self, path: &Path) -> Result<()> {
        verify_file_security(path)?;

        let content = fs::read_to_string(path)
            .with_context(|| format!("Failed to read secret file {}", path.display()))?;

        self.parse_str(&content, path.to_string_lossy().as_ref())
    }

    /// Parses a string formatted as KEY=VALUE pairs with strict fail-closed validation.
    pub fn parse_str(&mut self, content: &str, source_name: &str) -> Result<()> {
        for (line_idx, raw_line) in content.lines().enumerate() {
            let line_num = line_idx + 1;
            let mut line = raw_line.trim();

            if line.is_empty() || line.starts_with('#') {
                continue;
            }

            // Reject command injection / subshell execution
            if line.contains("$(")
                || line.contains('`')
                || line.contains(";;")
                || line.starts_with("function ")
            {
                bail!(
                    "Unsafe syntax detected in secret file '{}' at line {}: {}",
                    source_name,
                    line_num,
                    line
                );
            }

            // Strip optional 'export ' prefix
            if let Some(stripped) = line.strip_prefix("export ") {
                line = stripped.trim();
            }

            // Split on the first '='
            let (key, raw_val) = match line.split_once('=') {
                Some((k, v)) => (k.trim(), v.trim()),
                None => {
                    bail!(
                        "Invalid line format in secret file '{}' at line {}: missing '='",
                        source_name,
                        line_num
                    );
                }
            };

            // Validate POSIX identifier: ^[A-Za-z_][A-Za-z0-9_]*$
            if !is_valid_posix_identifier(key) {
                bail!(
                    "Invalid environment variable name '{}' at line {} in '{}'. Must match [A-Za-z_][A-Za-z0-9_]*",
                    key,
                    line_num,
                    source_name
                );
            }

            // Strip matching quotes or fail closed on unbalanced quotes
            let val = parse_quoted_value(raw_val).with_context(|| {
                format!(
                    "Mismatched or unclosed quotes at line {} in '{}'",
                    line_num, source_name
                )
            })?;

            self.entries.insert(key.to_string(), SecretValue(val));
        }

        Ok(())
    }
}

/// Validates that a string is a standard POSIX identifier.
fn is_valid_posix_identifier(key: &str) -> bool {
    if key.is_empty() {
        return false;
    }
    let mut chars = key.chars();
    let first = chars.next().unwrap();
    if !(first.is_ascii_alphabetic() || first == '_') {
        return false;
    }
    chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

/// Strips matching surrounding single or double quotes.
/// Fails closed if quotes are mismatched or unclosed.
fn parse_quoted_value(val: &str) -> Result<String> {
    if val.is_empty() {
        return Ok(String::new());
    }

    let starts_double = val.starts_with('"');
    let ends_double = val.ends_with('"');
    let starts_single = val.starts_with('\'');
    let ends_single = val.ends_with('\'');

    if starts_double || ends_double || starts_single || ends_single {
        if starts_double && ends_double && val.len() >= 2 {
            return Ok(val[1..val.len() - 1].to_string());
        }
        if starts_single && ends_single && val.len() >= 2 {
            return Ok(val[1..val.len() - 1].to_string());
        }
        bail!("Unclosed quote detected in value: {}", val);
    }

    Ok(val.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_posix_identifier() {
        assert!(is_valid_posix_identifier("API_KEY"));
        assert!(is_valid_posix_identifier("_SECRET_123"));
        assert!(!is_valid_posix_identifier("123_INVALID"));
        assert!(!is_valid_posix_identifier("KEY-NAME"));
        assert!(!is_valid_posix_identifier("KEY NAME"));
    }

    #[test]
    fn test_quote_parsing() {
        assert_eq!(parse_quoted_value("\"hello\"").unwrap(), "hello");
        assert_eq!(parse_quoted_value("'world'").unwrap(), "world");
        assert_eq!(parse_quoted_value("plain_val").unwrap(), "plain_val");
        assert!(parse_quoted_value("\"unclosed").is_err());
        assert!(parse_quoted_value("'mismatched\"").is_err());
    }

    #[test]
    fn test_secret_parsing_safety() {
        let mut store = SecretStore::new();
        let content = r#"
        # Sample configuration
        export OPENAI_API_KEY="sk-12345"
        ANTHROPIC_KEY='ant-67890'
        EMPTY_VAR=
        "#;
        store.parse_str(content, "test.env").unwrap();
        assert_eq!(store.entries.get("OPENAI_API_KEY").unwrap().0, "sk-12345");
        assert_eq!(store.entries.get("ANTHROPIC_KEY").unwrap().0, "ant-67890");
        assert_eq!(store.entries.get("EMPTY_VAR").unwrap().0, "");

        // Command injection attempt must fail
        let malicious = "BAD_KEY=$(rm -rf /)";
        assert!(store.parse_str(malicious, "attack.env").is_err());
    }
}
