#![feature(plugin)]
#![plugin(rocket_codegen)]

extern crate rocket;
extern crate rocket_contrib;
extern crate serde;
#[macro_use]
extern crate serde_derive;
extern crate serde_json;

mod questions;
mod error;
mod cors;

use rocket_contrib::JSON;
use std::sync::RwLock;

pub use error::DQError;
pub use cors::CORS;

#[derive(Serialize, Deserialize, Clone)]
pub struct Question {
    user: String,
    week: u8,
    text: String,
}

type QuestionResponse = CORS<Result<JSON<Vec<Question>>, String>>;
type SyncDB = RwLock<questions::QuestionDB>;

#[get("/users")]
fn get_users(db: rocket::State<SyncDB>) -> CORS<Result<JSON<Vec<String>>, String>> {
    CORS::any(db.read()
    .map_err(DQError::from)
    .and_then(|db| db.get_users())
    .map(JSON)
    .map_err(DQError::output))
}

#[get("/questions")]
fn get_all(db: rocket::State<SyncDB>) -> QuestionResponse {
    CORS::any(db.read()
         .map_err(DQError::from)
         .and_then(|db| db.get_all_questions())
         .map(JSON)
         .map_err(DQError::output))
}

#[get("/questions/<user>/<week>")]
fn get(user: &str, week: u8, db: rocket::State<SyncDB>) -> QuestionResponse {
    CORS::any(db.read()
         .map_err(DQError::from)
         .and_then(|db| db.get_questions(user, week))
         .map(JSON)
         .map_err(DQError::output))
}

#[route(OPTIONS, "/questions/<user>/<week>")]
#[allow(unused_variables)]
fn cors_preflight(user: &str, week: u8) -> cors::PreflightCORS {
    cors::CORS::preflight("*")
        .methods(vec![rocket::http::Method::Options, rocket::http::Method::Post, rocket::http::Method::Get].as_slice())
        .headers(vec!["Content-Type","content-type"].as_slice())
}

#[post("/questions/<user>/<week>", format = "application/json", data = "<questions>")]
fn set(user: &str, week: u8, questions: JSON<Vec<Question>>, db: rocket::State<SyncDB>) -> QuestionResponse {
    CORS::any(db.write()
         .map_err(DQError::from)
         .and_then(|mut db| db.set_questions(user, week, questions.clone()))
         .map(|_| questions)
         .map_err(DQError::output))
}

fn main() {
    rocket::ignite()
        .manage(RwLock::new(questions::QuestionDB::new("db".to_string())))
        .mount("/", routes![get_users, get_all, get, set,cors_preflight]).launch();
}
