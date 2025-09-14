use std::fs;
use std::path::PathBuf;
use std::process::Command;

use clap::{Parser, Subcommand};
use dirs;

const _CONFIG: &str = ".config/doc.conf";

/// Simplified docker and docker-compose wrapper
#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// List available containers
    List,

    /// Start the container
    Start { container: String },

    /// Open a shell in the container
    Shell { container: String },

    /// Stop the container
    Stop { container: String },

    /// Remove the container and image
    Remove { container: String },

    /// Show logs for the container
    Logs { container: String },

    /// Run a command within the container
    Run {
        container: String,
        command: Vec<String>,
    },
}

enum Action {
    Up,
    Down,
    Logs,
    Exec,
}

fn get_path() -> PathBuf {
    if let Some(home) = dirs::home_dir() {
        if let Ok(path) = fs::read_to_string(&home.join(_CONFIG)) {
            let trimmed = path.trim();
            if !trimmed.is_empty() {
                return PathBuf::from(trimmed);
            }
        }

        println!("\x1b[1m\x1b[4m\x1b[31mError:\x1b[0m");
        println!(
            "  Unable to find the file: `\x1b[1m{}\x1b[0m` in your home directory.",
            _CONFIG
        );
        println!("  The file should contain the path to directory with docker-compose in its subdirectories.");
        println!();
        println!(
            "  Example creation: `\x1b[1mecho \"/path/to/the/repository/root\" >> ~/.config/doc.conf\x1b[0m`."
        );
        std::process::exit(1);
    }
    println!("\x1b[1m\x1b[4m\x1b[31mError:\x1b[0m");
    println!("  Unable to access your home directory!");
    std::process::exit(1);
}

fn main() {
    let root = get_path();
    let cli = Cli::parse();

    match &cli.command {
        Commands::List => {
            if let Ok(entries) = fs::read_dir(&root) {
                println!("\x1b[1m\x1b[4mAvailable containers:\x1b[0m");
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() && path.join("docker-compose.yml").exists() {
                        if let Some(name) = path.file_name() {
                            println!("  \x1b[1m{}\x1b[0m", name.to_string_lossy());
                        }
                    }
                }
            }
        }
        Commands::Start { container } => execute(&root, container, Action::Up, Some("-d"), false),
        Commands::Shell { container } => {
            execute(&root, container, Action::Exec, Some("/bin/bash"), false)
        }
        Commands::Stop { container } => execute(&root, container, Action::Down, None, false),
        Commands::Remove { container } => {
            execute(&root, container, Action::Down, Some("-v --rmi all"), false)
        }
        Commands::Logs { container } => execute(&root, container, Action::Logs, None, false),
        Commands::Run { container, command } => {
            execute(&root, container, Action::Up, Some("-d"), true);
            execute(
                &root,
                container,
                Action::Exec,
                Some(command.join(" ").as_str()),
                true,
            );
            execute(&root, container, Action::Down, None, false)
        }
    }
}

fn execute(root: &PathBuf, container: &str, action: Action, args: Option<&str>, chained: bool) {
    let compose = root.join(container).join("docker-compose.yml");
    if !compose.exists() {
        eprintln!(
            "\x1b[31mError:\x1b[0m docker-compose.yml not found for container: {}",
            container
        );
        std::process::exit(1);
    }

    let mut cmd = Command::new("docker-compose");

    cmd.arg("-f").arg(&*compose.to_string_lossy());
    match action {
        Action::Exec => {
            cmd.arg(&"exec");
            cmd.arg(container);
        }
        Action::Up => {
            cmd.arg(&"up");
        }
        Action::Down => {
            cmd.arg(&"down");
        }
        Action::Logs => {
            cmd.arg(&"logs");
        }
    }
    if let Some(args) = args {
        cmd.args(args.split_whitespace());
    }

    let status = cmd.status().expect("Failed to run docker-compose");
    if !chained {
        std::process::exit(status.code().unwrap_or(1));
    } else if status.code().unwrap_or(1) != 0 {
        eprintln!(
            "\x1b[31mError:\x1b[0m Command failed with status code: {}",
            status.code().unwrap_or(1)
        );
        std::process::exit(status.code().unwrap_or(1));
    }
}
