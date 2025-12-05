//! `SQLite` database connection and operations.
//!
//! The database is stored at `~/.clings/clings.db` and contains tables for:
//! - Statistics tracking
//! - Focus session history
//! - Sync operation queue
//!
//! Note: `clings.db` is the `SQLite` database file.

use rusqlite::Connection;

use crate::config::Paths;
use crate::error::ClingsError;

use super::migrations;

/// Database connection wrapper.
pub struct Database {
    conn: Connection,
}

impl Database {
    /// Open the database at the default location.
    ///
    /// Creates the database file and runs migrations if necessary.
    ///
    /// # Errors
    ///
    /// Returns an error if the database cannot be opened or migrations fail.
    pub fn open() -> Result<Self, ClingsError> {
        let paths = Paths::new()?;
        paths.ensure_dirs()?;
        Self::open_at(&paths.database)
    }

    /// Open the database at a specific path.
    ///
    /// Creates the database file and runs migrations if necessary.
    ///
    /// # Errors
    ///
    /// Returns an error if the database cannot be opened or migrations fail.
    pub fn open_at(path: &std::path::Path) -> Result<Self, ClingsError> {
        let conn = Connection::open(path).map_err(|e| {
            ClingsError::Database(format!("Failed to open database {}: {e}", path.display()))
        })?;

        // Enable foreign keys
        conn.execute_batch("PRAGMA foreign_keys = ON;")
            .map_err(|e| ClingsError::Database(format!("Failed to enable foreign keys: {e}")))?;

        let db = Self { conn };
        db.migrate()?;

        Ok(db)
    }

    /// Open an in-memory database (useful for testing).
    ///
    /// # Errors
    ///
    /// Returns an error if the database cannot be opened or migrations fail.
    pub fn open_in_memory() -> Result<Self, ClingsError> {
        let conn = Connection::open_in_memory().map_err(|e| {
            ClingsError::Database(format!("Failed to open in-memory database: {e}"))
        })?;

        conn.execute_batch("PRAGMA foreign_keys = ON;")
            .map_err(|e| ClingsError::Database(format!("Failed to enable foreign keys: {e}")))?;

        let db = Self { conn };
        db.migrate()?;

        Ok(db)
    }

    /// Run database migrations.
    fn migrate(&self) -> Result<(), ClingsError> {
        migrations::run(&self.conn)
    }

    /// Get the current schema version.
    ///
    /// # Errors
    ///
    /// Returns an error if the version cannot be read.
    pub fn schema_version(&self) -> Result<i32, ClingsError> {
        migrations::get_version(&self.conn)
    }

    /// Get a reference to the underlying connection.
    ///
    /// This is primarily for use by feature modules that need direct access.
    #[must_use]
    pub const fn connection(&self) -> &Connection {
        &self.conn
    }

    /// Execute a query that returns no results.
    ///
    /// # Errors
    ///
    /// Returns an error if the query fails.
    pub fn execute(
        &self,
        sql: &str,
        params: &[&dyn rusqlite::ToSql],
    ) -> Result<usize, ClingsError> {
        self.conn
            .execute(sql, params)
            .map_err(|e| ClingsError::Database(format!("Query failed: {e}")))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_open_in_memory() {
        let db = Database::open_in_memory().unwrap();
        assert!(db.schema_version().unwrap() > 0);
    }

    #[test]
    fn test_open_file() {
        let temp_dir = tempfile::TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");

        let db = Database::open_at(&db_path).unwrap();
        assert!(db.schema_version().unwrap() > 0);
        assert!(db_path.exists());
    }

    #[test]
    fn test_reopen_database() {
        let temp_dir = tempfile::TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");

        // Open and close
        {
            let db = Database::open_at(&db_path).unwrap();
            assert!(db.schema_version().unwrap() > 0);
        }

        // Reopen - should not run migrations again
        {
            let db = Database::open_at(&db_path).unwrap();
            assert!(db.schema_version().unwrap() > 0);
        }
    }
}
