use serde_json;
use std::error::Error;
use std::fmt::{self,Display};
use std::io;
use std::sync::PoisonError;

#[derive(Debug)]
pub enum DQError {
    IO(io::Error),
    Json(serde_json::Error),
    Sync,
    QuestionsDisagree,
}

impl Display for DQError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        writeln!(f, "Notify <aozdemir@hmc.edu>")?;
        match self {
            &DQError::IO(ref e) => write!(f, "IO Error: {}", e),
            &DQError::Json(ref e) => write!(f, "Json Error: {}", e),
            &DQError::QuestionsDisagree => write!(f, "Questions must all have the same use and week"),
            &DQError::Sync => write!(f, "The database lock has been poisoned"),
        }
    }
}

impl Error for DQError {
    fn description(&self) -> &str {
        match self {
            &DQError::IO(ref e) => e.description(),
            &DQError::Json(ref e) => e.description(),
            &DQError::QuestionsDisagree => "Questions must all have the same use and week",
            &DQError::Sync => "A thread panicked with the lock",
        }
    }

    fn cause(&self) -> Option<&Error> {
        match self {
            &DQError::IO(ref e) => Some(e),
            &DQError::Json(ref e) => Some(e),
            _ => None,
        }
    }
}

impl From<io::Error> for DQError {
    fn from(err: io::Error) -> DQError {
        DQError::IO(err)
    }
}

impl From<serde_json::Error> for DQError {
    fn from(err: serde_json::Error) -> DQError {
        DQError::Json(err)
    }
}

impl<T> From<PoisonError<T>> for DQError {
    fn from(_: PoisonError<T>) -> DQError {
        DQError::Sync
    }
}

impl DQError {
    pub fn output(self) -> String {
        let s = format!("There was an error:\n{}\n{}", self, self.description());
        println!("\n{}", s);
        s
    }
}
