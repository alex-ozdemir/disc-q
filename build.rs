use std::process;

fn main() {
    println!("cargo:rerun-if-changed=./client/main.elm");
    println!("cargo:rerun-if-changed=./client/main.js");
    process::Command::new("elm-make")
        .arg("./main.elm")
        .arg("--output=./main.js")
        .arg("--yes")
        .current_dir("./client")
        .stdout(process::Stdio::inherit())
        .stderr(process::Stdio::inherit())
        .output()
        .map_err(|e| {
            println!("cargo:warning=The Elm client failed to build. See build.rs logs.");
            println!("The Elm client failed to build\n{}", e);
        }).ok();
}
