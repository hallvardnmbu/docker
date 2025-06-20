use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

use dirs;
use clap::{Parser, Subcommand};

const CONFIG_FILE: &str = ".docconfig";

/// Simple CLI to manage language-specific Docker Compose environments
#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    /// Project root directory (overrides config)
    #[arg(long, value_name = "DIR")]
    root: Option<PathBuf>,
    /// Override service name (default: language)
    #[arg(long, value_name = "NAME")]
    service: Option<String>,
}

#[derive(Subcommand)]
enum Commands {
    /// List available language subdirectories
    List,
    /// Build the docker image for a language
    Build { language: String, #[arg(trailing_var_arg = true)] extra: Vec<String> },
    /// Start the container for a language
    Start { language: String, #[arg(trailing_var_arg = true)] extra: Vec<String> },
    /// Open a shell in the container for a language
    Shell { language: String, #[arg(trailing_var_arg = true)] extra: Vec<String> },
    /// Stop the container for a language
    Stop { language: String, #[arg(trailing_var_arg = true)] extra: Vec<String> },
    /// Clean up containers, images, and volumes for a language
    Clean { language: String, #[arg(trailing_var_arg = true)] extra: Vec<String> },
    /// Show logs for a language
    Logs { language: String, #[arg(trailing_var_arg = true)] extra: Vec<String> },
    /// Setup the project root path
    Setup,
    /// Setup NordVPN OpenVPN config and service credentials for torrenting
    VpnSetup,
}

fn main() {
    let cli = Cli::parse();
    match &cli.command {
        Commands::Setup => {
            setup_config();
            return;
        }
        Commands::VpnSetup => {
            setup_vpn_config(&resolve_root(cli.root.as_ref()));
            return;
        }
        _ => {}
    }
    let root = resolve_root(cli.root.as_ref());
    match &cli.command {
        Commands::List => {
            println!("Available languages:");
            if let Ok(entries) = fs::read_dir(&root) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    if path.is_dir() && path.join("docker-compose.yml").exists() {
                        if let Some(name) = path.file_name() {
                            println!("- {}", name.to_string_lossy());
                        }
                    }
                }
            }
        }
        Commands::Build { language, extra } => run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "build", extra),
        Commands::Start { language, extra } => {
            let mut args = vec!["-d".to_string()];
            args.extend(extra.iter().cloned());
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "up", &args)
        },
        Commands::Shell { language, extra } => {
            let mut args = vec!["/bin/bash".to_string()];
            args.extend(extra.iter().cloned());
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "exec", &args)
        },
        Commands::Stop { language, extra } => run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "down", extra),
        Commands::Clean { language, extra } => {
            let mut args = vec!["-v".to_string(), "--rmi".to_string(), "all".to_string()];
            args.extend(extra.iter().cloned());
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "down", &args)
        },
        Commands::Logs { language, extra } => run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "logs", extra),
        Commands::Setup => unreachable!(),
        Commands::VpnSetup => unreachable!(),
    }
}

fn resolve_root(cli_root: Option<&PathBuf>) -> PathBuf {
    if let Some(root) = cli_root {
        return root.clone();
    }
    // Try to read from config file in home dir
    if let Some(home) = dirs::home_dir() {
        let config_path = home.join(CONFIG_FILE);
        if let Ok(path) = fs::read_to_string(&config_path) {
            let trimmed = path.trim();
            if !trimmed.is_empty() {
                return PathBuf::from(trimmed);
            }
        }
    }
    // Fallback: current dir
    env::current_dir().expect("Failed to get current directory")
}

fn setup_config() {
    println!("Enter the absolute path to your project root (where language subdirs are):");
    print!("> ");
    io::stdout().flush().unwrap();
    let mut input = String::new();
    io::stdin().read_line(&mut input).unwrap();
    let path = input.trim();
    if !Path::new(path).is_dir() {
        eprintln!("\x1b[31mError:\x1b[0m Not a valid directory: {}", path);
        std::process::exit(1);
    }
    if let Some(home) = dirs::home_dir() {
        let config_path = home.join(CONFIG_FILE);
        if let Err(e) = fs::write(&config_path, path) {
            eprintln!("\x1b[31mError:\x1b[0m Failed to write config: {}", e);
            std::process::exit(1);
        }
        println!("Saved project root to {}", config_path.display());
    } else {
        eprintln!("\x1b[31mError:\x1b[0m Could not determine home directory.");
        std::process::exit(1);
    }
}

fn setup_vpn_config(root: &PathBuf) {
    let vpn_dir = root.join("torrenting").join("data").join("vpn");
    
    // Create directory if it doesn't exist
    if let Err(e) = fs::create_dir_all(&vpn_dir) {
        eprintln!("\x1b[31mError:\x1b[0m Failed to create VPN directory: {}", e);
        std::process::exit(1);
    }
    
    let auth_file = vpn_dir.join("auth.txt");
    let ovpn_file = vpn_dir.join("nordvpn.ovpn");
    
    println!("NordVPN Setup for Secure Torrenting");
    println!("=====================================");
    println!();
    println!("Required files:");
    println!("1. NordVPN OpenVPN configuration file (.ovpn)");
    println!("2. NordVPN service credentials");
    println!();
    
    // Check if OpenVPN config exists
    if !ovpn_file.exists() {
        println!("OpenVPN configuration not found.");
        println!();
        println!("Download your .ovpn file from:");
        println!("https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/openvpn/");
        println!();
        println!("Place it at: {}", ovpn_file.display());
        println!();
    } else {
        println!("OpenVPN configuration found: {}", ovpn_file.display());
    }
    
    // Setup auth file
    println!("Setting up NordVPN service credentials...");
    println!();
    println!("Get your service credentials from:");
    println!("https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/service-credentials/");
    println!();
    
    print!("Service Username: ");
    io::stdout().flush().unwrap();
    let mut username = String::new();
    io::stdin().read_line(&mut username).unwrap();
    let username = username.trim();
    
    if username.is_empty() {
        eprintln!("\x1b[31mError:\x1b[0m Username cannot be empty");
        std::process::exit(1);
    }
    
    print!("Service Password: ");
    io::stdout().flush().unwrap();
    let mut password = String::new();
    io::stdin().read_line(&mut password).unwrap();
    let password = password.trim();
    
    if password.is_empty() {
        eprintln!("\x1b[31mError:\x1b[0m Password cannot be empty");
        std::process::exit(1);
    }
    
    let auth_content = format!("{}\n{}\n", username, password);
    
    if let Err(e) = fs::write(&auth_file, auth_content) {
        eprintln!("\x1b[31mError:\x1b[0m Failed to write auth file: {}", e);
        std::process::exit(1);
    }
    
    // Set secure permissions on auth file
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(&auth_file).unwrap().permissions();
        perms.set_mode(0o600);
        fs::set_permissions(&auth_file, perms).unwrap();
    }
    
    println!("Credentials saved to: {}", auth_file.display());
    println!();
    
    // Summary
    if ovpn_file.exists() {
        println!("Setup complete. Both files are ready:");
        println!("  OpenVPN config: {}", ovpn_file.display());
        println!("  Credentials: {}", auth_file.display());
        println!();
        println!("Start the container: doc start torrenting");
        println!("Access Web UI: http://localhost:8081 (admin/adminadmin)");
    } else {
        println!("Setup incomplete. You still need to:");
        println!("  1. Download your NordVPN .ovpn file");
        println!("  2. Place it at: {}", ovpn_file.display());
        println!();
        println!("Then run: doc start torrenting");
    }
}

fn run_compose(root: &PathBuf, service: &str, language: &str, action: &str, extra: &Vec<String>) {
    let compose_file = root.join(language).join("docker-compose.yml");
    if !compose_file.exists() {
        eprintln!("\x1b[31mError:\x1b[0m docker-compose.yml not found for language: {}", language);
        std::process::exit(1);
    }
    let compose_file_str = compose_file.to_string_lossy();
    let mut cmd = Command::new("docker-compose");
    cmd.arg("-f").arg(&*compose_file_str);
    match action {
        "exec" => {
            cmd.arg(action).arg(service);
            for arg in extra {
                cmd.arg(arg);
            }
        },
        _ => {
            cmd.arg(action);
            for arg in extra {
                cmd.arg(arg);
            }
        }
    }
    let status = cmd.status().expect("Failed to run docker-compose");
    std::process::exit(status.code().unwrap_or(1));
}
