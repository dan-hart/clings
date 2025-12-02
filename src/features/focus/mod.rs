//! Focus mode and session tracking.
//!
//! Provides focused work sessions with time tracking:
//! - Start/stop/pause focus sessions
//! - Pomodoro-style timed sessions
//! - Session history and reports
//! - Break reminders

pub mod report;
pub mod session;
pub mod storage;
pub mod timer;

pub use report::{FocusReport, ReportPeriod};
pub use session::{FocusSession, SessionState, SessionType};
pub use storage::FocusStorage;
pub use timer::{format_duration, parse_duration, Timer, TimerState};
