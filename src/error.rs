use thiserror::Error;

#[derive(Error, Debug)]
pub enum ClingsError {
    #[error(
        "Things 3 is not installed.\n\n\
         clings requires Things 3 for Mac to function.\n\n\
         Get Things 3 from:\n\
         • Mac App Store: https://apps.apple.com/app/things-3/id904280696\n\
         • Cultured Code: https://culturedcode.com/things/"
    )]
    ThingsNotInstalled,

    #[error("Things 3 is not running. Please launch Things 3 and try again.")]
    ThingsNotRunning,

    #[error(
        "Automation permission required.\n\n\
         clings needs permission to communicate with Things 3.\n\
         This is a one-time setup.\n\n\
         1. Open System Settings > Privacy & Security > Automation\n\
         2. Enable \"Things 3\" under your terminal application\n\
         3. Run clings again\n\n\
         Tip: Run this command to open settings directly:\n\
         open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Automation\""
    )]
    PermissionDenied,

    #[error("Item not found: {0}")]
    NotFound(String),

    #[error("Script execution failed: {0}")]
    Script(String),

    #[error("Failed to parse response: {0}")]
    Parse(#[from] serde_json::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Database error: {0}")]
    Database(String),

    #[error("Filter error: {0}")]
    Filter(String),

    #[error("Bulk operation error: {0}")]
    BulkOperation(String),

    #[error("Feature not supported: {0}")]
    NotSupported(String),

    #[error("Invalid argument: {0}")]
    InvalidArgument(String),
}

impl ClingsError {
    /// Classify an error from osascript stderr output
    #[must_use]
    pub fn from_stderr(stderr: &str) -> Self {
        // Error -1743: Automation permission denied
        if stderr.contains("-1743") || stderr.contains("not authorized") {
            return Self::PermissionDenied;
        }

        // Things not installed (no application bundle found)
        if stderr.contains("Can't get application")
            || stderr.contains("Application can't be found")
            || stderr.contains("unable to find application")
        {
            return Self::ThingsNotInstalled;
        }

        // Things not running
        if stderr.contains("Application isn't running")
            || stderr.contains("connection is invalid")
            || stderr.contains("is not running")
        {
            return Self::ThingsNotRunning;
        }

        // Can't get item
        if stderr.contains("Can't get") {
            let msg = stderr
                .lines()
                .find(|l| l.contains("Can't get"))
                .unwrap_or(stderr)
                .to_string();
            return Self::NotFound(msg);
        }

        Self::Script(stderr.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Tests for ClingsError::from_stderr() function

    #[test]
    fn test_from_stderr_permission_denied_error_code() {
        let err = ClingsError::from_stderr(
            "execution error: Error -1743: Not authorized to send Apple events to Things3.",
        );
        assert!(matches!(err, ClingsError::PermissionDenied));
    }

    #[test]
    fn test_from_stderr_permission_denied_not_authorized() {
        let err = ClingsError::from_stderr(
            "System Events got an error: not authorized to perform this action",
        );
        assert!(matches!(err, ClingsError::PermissionDenied));
    }

    #[test]
    fn test_from_stderr_things_not_installed_cant_get() {
        let err = ClingsError::from_stderr("Can't get application \"Things3\". (-1728)");
        assert!(matches!(err, ClingsError::ThingsNotInstalled));
    }

    #[test]
    fn test_from_stderr_things_not_installed_cant_be_found() {
        let err = ClingsError::from_stderr("Application can't be found in the Finder");
        assert!(matches!(err, ClingsError::ThingsNotInstalled));
    }

    #[test]
    fn test_from_stderr_things_not_installed_unable_to_find() {
        let err = ClingsError::from_stderr("osascript: unable to find application Things3");
        assert!(matches!(err, ClingsError::ThingsNotInstalled));
    }

    #[test]
    fn test_from_stderr_things_not_running_isnt_running() {
        let err = ClingsError::from_stderr("Application isn't running. (-600)");
        assert!(matches!(err, ClingsError::ThingsNotRunning));
    }

    #[test]
    fn test_from_stderr_things_not_running_connection_invalid() {
        let err = ClingsError::from_stderr("The connection is invalid.");
        assert!(matches!(err, ClingsError::ThingsNotRunning));
    }

    #[test]
    fn test_from_stderr_things_not_running_is_not_running() {
        let err = ClingsError::from_stderr("Things3 is not running");
        assert!(matches!(err, ClingsError::ThingsNotRunning));
    }

    #[test]
    fn test_from_stderr_cant_get_item_single_line() {
        let err = ClingsError::from_stderr("Can't get todo \"invalid-id\"");
        if let ClingsError::NotFound(msg) = err {
            assert_eq!(msg, "Can't get todo \"invalid-id\"");
        } else {
            panic!("Expected NotFound error");
        }
    }

    #[test]
    fn test_from_stderr_cant_get_item_multiline() {
        let stderr = "execution error: Can't get project \"xyz\". (-1728)\n\
                      at line 5";
        let err = ClingsError::from_stderr(stderr);
        if let ClingsError::NotFound(msg) = err {
            assert!(msg.contains("Can't get project"));
        } else {
            panic!("Expected NotFound error");
        }
    }

    #[test]
    fn test_from_stderr_fallback_to_script_error() {
        let err = ClingsError::from_stderr("Some unexpected error occurred");
        if let ClingsError::Script(msg) = err {
            assert_eq!(msg, "Some unexpected error occurred");
        } else {
            panic!("Expected Script error");
        }
    }

    #[test]
    fn test_from_stderr_empty_string() {
        let err = ClingsError::from_stderr("");
        assert!(matches!(err, ClingsError::Script(_)));
    }

    // Tests for Error Display implementations

    #[test]
    fn test_display_things_not_installed_contains_app_store_url() {
        let err = ClingsError::ThingsNotInstalled;
        let display = format!("{err}");
        assert!(display.contains("https://apps.apple.com/app/things-3/id904280696"));
        assert!(display.contains("https://culturedcode.com/things/"));
        assert!(display.contains("Things 3 is not installed"));
    }

    #[test]
    fn test_display_things_not_running() {
        let err = ClingsError::ThingsNotRunning;
        let display = format!("{err}");
        assert_eq!(
            display,
            "Things 3 is not running. Please launch Things 3 and try again."
        );
    }

    #[test]
    fn test_display_permission_denied_contains_instructions() {
        let err = ClingsError::PermissionDenied;
        let display = format!("{err}");
        assert!(display.contains("Automation permission required"));
        assert!(display.contains("System Settings > Privacy & Security > Automation"));
        assert!(display.contains("Enable \"Things 3\""));
        assert!(display.contains(
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ));
    }

    #[test]
    fn test_display_not_found() {
        let err = ClingsError::NotFound("todo-123".to_string());
        let display = format!("{err}");
        assert_eq!(display, "Item not found: todo-123");
    }

    #[test]
    fn test_display_script() {
        let err = ClingsError::Script("syntax error".to_string());
        let display = format!("{err}");
        assert_eq!(display, "Script execution failed: syntax error");
    }

    #[test]
    fn test_display_config() {
        let err = ClingsError::Config("invalid config file".to_string());
        let display = format!("{err}");
        assert_eq!(display, "Configuration error: invalid config file");
    }

    #[test]
    fn test_display_database() {
        let err = ClingsError::Database("connection failed".to_string());
        let display = format!("{err}");
        assert_eq!(display, "Database error: connection failed");
    }

    #[test]
    fn test_display_filter() {
        let err = ClingsError::Filter("invalid tag filter".to_string());
        let display = format!("{err}");
        assert_eq!(display, "Filter error: invalid tag filter");
    }

    #[test]
    fn test_display_bulk_operation() {
        let err = ClingsError::BulkOperation("failed to update 3 items".to_string());
        let display = format!("{err}");
        assert_eq!(display, "Bulk operation error: failed to update 3 items");
    }

    #[test]
    fn test_display_not_supported() {
        let err = ClingsError::NotSupported("recurring todos".to_string());
        let display = format!("{err}");
        assert_eq!(display, "Feature not supported: recurring todos");
    }

    // Tests for error classification priority

    #[test]
    fn test_from_stderr_priority_permission_over_others() {
        // Permission denied should take priority
        let err = ClingsError::from_stderr("Error -1743: Can't get application");
        assert!(matches!(err, ClingsError::PermissionDenied));
    }

    #[test]
    fn test_from_stderr_priority_not_installed_over_not_running() {
        // Not installed should take priority over not running
        let err =
            ClingsError::from_stderr("Can't get application Things3 - Application isn't running");
        assert!(matches!(err, ClingsError::ThingsNotInstalled));
    }

    #[test]
    fn test_from_stderr_priority_not_running_over_cant_get() {
        // Not running should take priority over can't get item
        let err = ClingsError::from_stderr("Application isn't running - Can't get todo");
        assert!(matches!(err, ClingsError::ThingsNotRunning));
    }
}
