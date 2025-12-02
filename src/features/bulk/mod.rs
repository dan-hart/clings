//! Bulk operations for Things 3 items.
//!
//! This module provides bulk operations that can be applied to multiple items
//! at once, filtered by a query expression.

mod operations;

pub use operations::{
    BulkAction, BulkOperation, BulkResult, BulkSummary, execute_bulk_operation,
};
