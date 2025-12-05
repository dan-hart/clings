//! Storage for automation rules.
//!
//! Persists rules to YAML files in the config directory.

use std::fs;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use super::rule::Rule;
use crate::config::Paths;
use crate::error::ClingsError;

/// Storage for automation rules.
pub struct RuleStorage {
    rules_dir: PathBuf,
}

impl RuleStorage {
    /// Create a new rule storage.
    ///
    /// # Errors
    ///
    /// Returns an error if the config directory cannot be accessed.
    pub fn new() -> Result<Self, ClingsError> {
        let paths = Paths::new()?;
        let rules_dir = paths.root.join("rules");

        // Ensure rules directory exists
        if !rules_dir.exists() {
            fs::create_dir_all(&rules_dir).map_err(|e| {
                ClingsError::Config(format!("Failed to create rules directory: {e}"))
            })?;
        }

        Ok(Self { rules_dir })
    }

    /// Create storage with a custom directory.
    #[must_use]
    pub const fn with_dir(rules_dir: PathBuf) -> Self {
        Self { rules_dir }
    }

    /// Save a rule to disk.
    ///
    /// # Errors
    ///
    /// Returns an error if the rule cannot be saved.
    pub fn save(&self, rule: &Rule) -> Result<(), ClingsError> {
        let filename = Self::rule_filename(&rule.name);
        let path = self.rules_dir.join(&filename);

        let yaml = serde_yaml::to_string(rule)
            .map_err(|e| ClingsError::Config(format!("Failed to serialize rule: {e}")))?;

        fs::write(&path, yaml)
            .map_err(|e| ClingsError::Config(format!("Failed to write rule file: {e}")))?;

        Ok(())
    }

    /// Load a rule by name.
    ///
    /// # Errors
    ///
    /// Returns an error if the rule cannot be loaded.
    pub fn load(&self, name: &str) -> Result<Option<Rule>, ClingsError> {
        let filename = Self::rule_filename(name);
        let path = self.rules_dir.join(&filename);

        if !path.exists() {
            return Ok(None);
        }

        let yaml = fs::read_to_string(&path)
            .map_err(|e| ClingsError::Config(format!("Failed to read rule file: {e}")))?;

        let rule: Rule = serde_yaml::from_str(&yaml)
            .map_err(|e| ClingsError::Config(format!("Failed to parse rule: {e}")))?;

        Ok(Some(rule))
    }

    /// List all rules.
    ///
    /// # Errors
    ///
    /// Returns an error if rules cannot be listed.
    pub fn list(&self) -> Result<Vec<Rule>, ClingsError> {
        let mut rules = Vec::new();

        let entries = fs::read_dir(&self.rules_dir)
            .map_err(|e| ClingsError::Config(format!("Failed to read rules directory: {e}")))?;

        for entry in entries {
            let entry =
                entry.map_err(|e| ClingsError::Config(format!("Failed to read entry: {e}")))?;

            let path = entry.path();
            if path
                .extension()
                .is_some_and(|ext| ext == "yaml" || ext == "yml")
            {
                let yaml = fs::read_to_string(&path)
                    .map_err(|e| ClingsError::Config(format!("Failed to read rule: {e}")))?;

                match serde_yaml::from_str::<Rule>(&yaml) {
                    Ok(rule) => rules.push(rule),
                    Err(e) => {
                        // Log but don't fail for individual rule parse errors
                        eprintln!("Warning: Failed to parse rule {}: {e}", path.display());
                    },
                }
            }
        }

        // Sort by priority
        rules.sort_by_key(|r| r.priority);

        Ok(rules)
    }

    /// Delete a rule by name.
    ///
    /// # Errors
    ///
    /// Returns an error if the rule cannot be deleted.
    pub fn delete(&self, name: &str) -> Result<bool, ClingsError> {
        let filename = Self::rule_filename(name);
        let path = self.rules_dir.join(&filename);

        if !path.exists() {
            return Ok(false);
        }

        fs::remove_file(&path)
            .map_err(|e| ClingsError::Config(format!("Failed to delete rule: {e}")))?;

        Ok(true)
    }

    /// Get the path to a rule file.
    #[must_use]
    pub fn rule_path(&self, name: &str) -> PathBuf {
        self.rules_dir.join(Self::rule_filename(name))
    }

    /// Generate a filename for a rule.
    fn rule_filename(name: &str) -> String {
        // Sanitize the name for use as a filename
        let safe_name: String = name
            .chars()
            .map(|c| {
                if c.is_alphanumeric() || c == '-' || c == '_' {
                    c
                } else {
                    '_'
                }
            })
            .collect();

        format!("{safe_name}.yaml")
    }
}

/// Rule set for serialization.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleSet {
    /// Rules in this set
    pub rules: Vec<Rule>,
}

impl RuleSet {
    /// Create a new rule set.
    #[must_use]
    pub const fn new() -> Self {
        Self { rules: Vec::new() }
    }

    /// Add a rule.
    pub fn add(&mut self, rule: Rule) {
        self.rules.push(rule);
    }

    /// Export to YAML.
    ///
    /// # Errors
    ///
    /// Returns an error if serialization fails.
    pub fn to_yaml(&self) -> Result<String, ClingsError> {
        serde_yaml::to_string(self)
            .map_err(|e| ClingsError::Config(format!("Failed to serialize rules: {e}")))
    }

    /// Import from YAML.
    ///
    /// # Errors
    ///
    /// Returns an error if parsing fails.
    pub fn from_yaml(yaml: &str) -> Result<Self, ClingsError> {
        serde_yaml::from_str(yaml)
            .map_err(|e| ClingsError::Config(format!("Failed to parse rules: {e}")))
    }
}

impl Default for RuleSet {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::features::automation::rule::Trigger;
    use tempfile::TempDir;

    fn create_test_storage() -> (RuleStorage, TempDir) {
        let temp_dir = TempDir::new().unwrap();
        let storage = RuleStorage::with_dir(temp_dir.path().to_path_buf());
        (storage, temp_dir)
    }

    #[test]
    fn test_save_and_load() {
        let (storage, _temp) = create_test_storage();

        let rule = Rule::new("Test Rule", Trigger::manual()).with_description("A test rule");

        storage.save(&rule).unwrap();

        let loaded = storage.load("Test Rule").unwrap().unwrap();
        assert_eq!(loaded.name, "Test Rule");
        assert_eq!(loaded.description, Some("A test rule".to_string()));
    }

    #[test]
    fn test_list_rules() {
        let (storage, _temp) = create_test_storage();

        let rule1 = Rule::new("Rule 1", Trigger::manual()).with_priority(10);
        let rule2 = Rule::new("Rule 2", Trigger::manual()).with_priority(5);

        storage.save(&rule1).unwrap();
        storage.save(&rule2).unwrap();

        let rules = storage.list().unwrap();
        assert_eq!(rules.len(), 2);
        // Should be sorted by priority
        assert_eq!(rules[0].name, "Rule 2");
        assert_eq!(rules[1].name, "Rule 1");
    }

    #[test]
    fn test_delete_rule() {
        let (storage, _temp) = create_test_storage();

        let rule = Rule::new("To Delete", Trigger::manual());
        storage.save(&rule).unwrap();

        assert!(storage.delete("To Delete").unwrap());
        assert!(storage.load("To Delete").unwrap().is_none());
    }

    #[test]
    fn test_rule_set() {
        let mut set = RuleSet::new();
        set.add(Rule::new("Rule 1", Trigger::manual()));
        set.add(Rule::new("Rule 2", Trigger::manual()));

        let yaml = set.to_yaml().unwrap();
        assert!(yaml.contains("Rule 1"));
        assert!(yaml.contains("Rule 2"));

        let parsed = RuleSet::from_yaml(&yaml).unwrap();
        assert_eq!(parsed.rules.len(), 2);
    }
}
