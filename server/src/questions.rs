use super::{DQError, Question};

use std::fs::{read_dir,create_dir_all,File};
use std::io::ErrorKind;
use std::path::PathBuf;
use std::str::FromStr;
use serde_json;

pub struct QuestionDB {
    path: String,
}

impl QuestionDB {
    pub fn new(path: String) -> Self {
        create_dir_all(&path).ok();
        QuestionDB { path }
    }

    pub fn set_questions(&mut self, user: &str, week: u8, qs: Vec<Question>) -> Result<(), DQError> {
        if qs.iter().any(|q| q.user != *user || q.week != week) {
            return Err(DQError::QuestionsDisagree)
        }
        let p = self.path_buf(user, week);
        create_dir_all(p.parent().unwrap())?;
        let mut file = File::create(p).map_err(DQError::IO)?;
        serde_json::to_writer_pretty(&mut file, &qs).map_err(DQError::Json)
    }

    fn path_buf(&self, user: &str, week: u8) -> PathBuf {
        let mut p = PathBuf::from(&self.path);
        p.push(user);
        p.push(format!("{}", week));
        p
    }

    pub fn get_questions(&self, user: &str, week: u8) -> Result<Vec<Question>, DQError> {
        match File::open(self.path_buf(user, week)) {
            Ok(ref mut file) => {
                Ok(serde_json::from_reader(file)?)
            }
            Err(ref err) if err.kind() == ErrorKind::NotFound => {
                Ok(vec![])
            }
            Err(err) => Err(DQError::IO(err))
        }
    }

    pub fn get_all_questions(&self) -> Result<Vec<Question>, DQError> {
        create_dir_all(&self.path)?;
        let mut qs: Vec<Question> = Vec::new();
        for user_entry in read_dir(&self.path).map_err(DQError::IO)? {
            let user_entry = user_entry.map_err(DQError::IO)?;
            for week_entry in read_dir(user_entry.path()).map_err(DQError::IO)? {
                let week_entry = week_entry.map_err(DQError::IO)?;
                let file = File::open(week_entry.path()).map_err(DQError::IO)?;
                if let Ok(_) = u8::from_str(&week_entry.file_name().to_string_lossy()) {
                    qs.extend(serde_json::from_reader::<_,Vec<Question>>(file)?);
                }
            }
        }
        Ok(qs)
    }

    pub fn get_users(&self) -> Result<Vec<String>, DQError> {
        let mut out = Vec::new();
        for dir_entry in read_dir(&self.path)? {
            out.push(dir_entry?.file_name().to_string_lossy().into_owned())
        }
        Ok(out)
    }
}
