//! Template storage and persistence.
//!
//! Templates are stored as individual YAML files in `~/.clings/templates/`.

use std::path::PathBuf;

use crate::config::Paths;
use crate::error::ClingsError;

use super::ProjectTemplate;

/// Manages template storage in the filesystem.
pub struct TemplateStorage {
    /// Path to templates directory.
    templates_dir: PathBuf,
}

impl TemplateStorage {
    /// Create a new template storage.
    ///
    /// # Errors
    ///
    /// Returns an error if the templates directory cannot be created.
    pub fn new() -> Result<Self, ClingsError> {
        let paths = Paths::default();
        paths.ensure_dirs()?;

        Ok(Self {
            templates_dir: paths.templates,
        })
    }

    /// Create template storage with a custom directory (for testing).
    #[must_use]
    pub fn with_dir(dir: PathBuf) -> Self {
        Self { templates_dir: dir }
    }

    /// Get the file path for a template.
    fn template_path(&self, name: &str) -> PathBuf {
        let safe_name = Self::sanitize_name(name);
        self.templates_dir.join(format!("{safe_name}.yaml"))
    }

    /// Sanitize a template name for use as a filename.
    fn sanitize_name(name: &str) -> String {
        name.chars()
            .map(|c| {
                if c.is_alphanumeric() || c == '-' || c == '_' {
                    c
                } else {
                    '_'
                }
            })
            .collect()
    }

    /// Save a template.
    ///
    /// # Errors
    ///
    /// Returns an error if the template cannot be serialized or written.
    pub fn save(&self, template: &ProjectTemplate) -> Result<(), ClingsError> {
        let path = self.template_path(&template.name);
        let content = serde_yaml::to_string(template)
            .map_err(|e| ClingsError::Config(format!("Failed to serialize template: {e}")))?;

        std::fs::write(&path, content).map_err(ClingsError::Io)?;
        Ok(())
    }

    /// Load a template by name.
    ///
    /// # Errors
    ///
    /// Returns an error if the template doesn't exist or cannot be loaded.
    pub fn load(&self, name: &str) -> Result<ProjectTemplate, ClingsError> {
        let path = self.template_path(name);

        if !path.exists() {
            return Err(ClingsError::NotFound(format!("Template '{name}'")));
        }

        let content = std::fs::read_to_string(&path).map_err(ClingsError::Io)?;
        let template: ProjectTemplate = serde_yaml::from_str(&content)
            .map_err(|e| ClingsError::Config(format!("Failed to parse template: {e}")))?;

        Ok(template)
    }

    /// Delete a template.
    ///
    /// # Errors
    ///
    /// Returns an error if the template doesn't exist or cannot be deleted.
    pub fn delete(&self, name: &str) -> Result<(), ClingsError> {
        let path = self.template_path(name);

        if !path.exists() {
            return Err(ClingsError::NotFound(format!("Template '{name}'")));
        }

        std::fs::remove_file(&path).map_err(ClingsError::Io)?;
        Ok(())
    }

    /// List all templates.
    ///
    /// # Errors
    ///
    /// Returns an error if the templates directory cannot be read.
    pub fn list(&self) -> Result<Vec<ProjectTemplate>, ClingsError> {
        if !self.templates_dir.exists() {
            return Ok(Vec::new());
        }

        let mut templates = Vec::new();

        let entries = std::fs::read_dir(&self.templates_dir).map_err(ClingsError::Io)?;

        for entry in entries {
            let entry = entry.map_err(ClingsError::Io)?;
            let path = entry.path();

            if path.extension().is_some_and(|ext| ext == "yaml") {
                let content = std::fs::read_to_string(&path).map_err(ClingsError::Io)?;
                if let Ok(template) = serde_yaml::from_str::<ProjectTemplate>(&content) {
                    templates.push(template);
                }
            }
        }

        // Sort by name
        templates.sort_by(|a, b| a.name.cmp(&b.name));

        Ok(templates)
    }

    /// Check if a template exists.
    #[must_use]
    pub fn exists(&self, name: &str) -> bool {
        self.template_path(name).exists()
    }

    /// Get template names only (faster than loading all templates).
    ///
    /// # Errors
    ///
    /// Returns an error if the templates directory cannot be read.
    pub fn list_names(&self) -> Result<Vec<String>, ClingsError> {
        if !self.templates_dir.exists() {
            return Ok(Vec::new());
        }

        let mut names = Vec::new();

        let entries = std::fs::read_dir(&self.templates_dir).map_err(ClingsError::Io)?;

        for entry in entries {
            let entry = entry.map_err(ClingsError::Io)?;
            let path = entry.path();

            if path.extension().is_some_and(|ext| ext == "yaml") {
                if let Some(stem) = path.file_stem() {
                    names.push(stem.to_string_lossy().to_string());
                }
            }
        }

        names.sort();
        Ok(names)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_sanitize_name() {
        assert_eq!(TemplateStorage::sanitize_name("Sprint"), "Sprint");
        assert_eq!(
            TemplateStorage::sanitize_name("Sprint Template"),
            "Sprint_Template"
        );
        assert_eq!(
            TemplateStorage::sanitize_name("Sprint/Template"),
            "Sprint_Template"
        );
        assert_eq!(TemplateStorage::sanitize_name("sprint-42"), "sprint-42");
    }

    #[test]
    fn test_save_and_load() {
        let temp_dir = TempDir::new().unwrap();
        let storage = TemplateStorage::with_dir(temp_dir.path().to_path_buf());

        let template = ProjectTemplate::new("Test Template")
            .with_description("A test template")
            .with_tags(vec!["test".to_string()]);

        storage.save(&template).unwrap();
        let loaded = storage.load("Test Template").unwrap();

        assert_eq!(loaded.name, "Test Template");
        assert_eq!(loaded.description, Some("A test template".to_string()));
        assert_eq!(loaded.tags, vec!["test".to_string()]);
    }

    #[test]
    fn test_delete() {
        let temp_dir = TempDir::new().unwrap();
        let storage = TemplateStorage::with_dir(temp_dir.path().to_path_buf());

        let template = ProjectTemplate::new("ToDelete");
        storage.save(&template).unwrap();

        assert!(storage.exists("ToDelete"));

        storage.delete("ToDelete").unwrap();
        assert!(!storage.exists("ToDelete"));
    }

    #[test]
    fn test_list() {
        let temp_dir = TempDir::new().unwrap();
        let storage = TemplateStorage::with_dir(temp_dir.path().to_path_buf());

        storage.save(&ProjectTemplate::new("Alpha")).unwrap();
        storage.save(&ProjectTemplate::new("Beta")).unwrap();
        storage.save(&ProjectTemplate::new("Gamma")).unwrap();

        let templates = storage.list().unwrap();
        assert_eq!(templates.len(), 3);
        assert_eq!(templates[0].name, "Alpha");
        assert_eq!(templates[1].name, "Beta");
        assert_eq!(templates[2].name, "Gamma");
    }

    #[test]
    fn test_list_names() {
        let temp_dir = TempDir::new().unwrap();
        let storage = TemplateStorage::with_dir(temp_dir.path().to_path_buf());

        storage.save(&ProjectTemplate::new("First")).unwrap();
        storage.save(&ProjectTemplate::new("Second")).unwrap();

        let names = storage.list_names().unwrap();
        assert_eq!(names.len(), 2);
        assert!(names.contains(&"First".to_string()));
        assert!(names.contains(&"Second".to_string()));
    }

    #[test]
    fn test_load_not_found() {
        let temp_dir = TempDir::new().unwrap();
        let storage = TemplateStorage::with_dir(temp_dir.path().to_path_buf());

        let result = storage.load("NonExistent");
        assert!(result.is_err());
    }
}
