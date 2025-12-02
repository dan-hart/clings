//! Sync queue for offline operations.
//!
//! This module provides functionality for queueing operations when Things 3
//! is unavailable or for batching operations for efficiency.
//!
//! Features:
//! - Queue any operation type (add, complete, cancel, update, etc.)
//! - Automatic retry with exponential backoff
//! - Conflict detection and resolution
//! - Batch execution with progress tracking

pub mod executor;
pub mod operation;
pub mod queue;

pub use executor::{format_sync_result, ExecutorConfig, SyncExecutor, SyncResult};
pub use operation::{Operation, OperationStatus, OperationType};
pub use queue::SyncQueue;
