use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

use dirs;
use clap::{Parser, Subcommand};

const CONFIG_FILE: &str = ".config/doc.conf";

/// Simple CLI to manage language-specific Docker Compose environments with VPN support
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
    /// Check container status and VPN connection
    Status { language: String },
    /// Test VPN and service functionality
    Test { language: String },
    /// Run a script and stop the container afterwards
    Run { language: String, command: Vec<String> }
}

fn main() {
    let cli = Cli::parse();
    match &cli.command {
        Commands::Status { language } => {
            check_status(&resolve_root(cli.root.as_ref()), language);
            return;
        }
        Commands::Test { language } => {
            test_functionality(&resolve_root(cli.root.as_ref()), language);
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
        Commands::Build { language, extra } => run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "build", extra, false),
        Commands::Start { language, extra } => {
            let mut args = vec!["-d".to_string()];
            args.extend(extra.iter().cloned());
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "up", &args, false)
        },
        Commands::Shell { language, extra } => {
            let mut args = vec!["/bin/bash".to_string()];
            args.extend(extra.iter().cloned());
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "exec", &args, false)
        },
        Commands::Stop { language, extra } => run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "down", extra, false),
        Commands::Clean { language, extra } => {
            let mut args = vec!["-v".to_string(), "--rmi".to_string(), "all".to_string()];
            args.extend(extra.iter().cloned());
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "down", &args, false)
        },
        Commands::Logs { language, extra } => run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "logs", extra, false),
        Commands::Status { .. } => unreachable!(),
        Commands::Test { .. } => unreachable!(),
        Commands::Run { language, command } => {
            // 1. Start the container (detached)
            let start_args = vec!["-d".to_string()];
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "up", &start_args, true);
            // 2. Execute the specified command (vector of strings)
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "exec", command, true);
            // 3. Stop the container
            let stop_args: Vec<String> = Vec::new();
            run_compose(&root, cli.service.as_deref().unwrap_or(language), language, "down", &stop_args, false)
        }
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

fn run_compose(
    root: &PathBuf, service: &str, language: &str, action: &str, extra: &Vec<String>, interactive: bool
) {
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
            // Special handling for JavaScript to run as playground user
            if language == "javascript" && extra.len() == 1 && extra[0] == "/bin/bash" {
                // Use docker directly for JavaScript to switch to playground user
                // For gluetun setup, use the javascript container name
                let container_name = format!("playground-{}", language);
                let mut docker_cmd = Command::new("docker");
                docker_cmd.args(&["exec", "-it", &container_name, "bash"]);
                let status = docker_cmd.status().expect("Failed to run docker exec");
                std::process::exit(status.code().unwrap_or(1));
            } else {
                cmd.arg(action).arg(service);
                for arg in extra {
                    cmd.arg(arg);
                }
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
    if !interactive {
        std::process::exit(status.code().unwrap_or(1));
    } else if status.code().unwrap_or(1) != 0 {
        eprintln!("\x1b[31mError:\x1b[0m Command failed with status code: {}", status.code().unwrap_or(1));
        std::process::exit(status.code().unwrap_or(1));
    }
}

fn check_status(root: &PathBuf, language: &str) {
    let supported_services = ["torrenting", "javascript"];
    if !supported_services.contains(&language) {
        eprintln!("\x1b[31mError:\x1b[0m Status check only available for: {}", supported_services.join(", "));
        std::process::exit(1);
    }
    
    let compose_file = root.join(language).join("docker-compose.yml");
    if !compose_file.exists() {
        eprintln!("\x1b[31mError:\x1b[0m docker-compose.yml not found for language: {}", language);
        std::process::exit(1);
    }
    
    println!("Checking {} container status...", language);
    
    // Check if this is a gluetun-based setup by looking at the compose file
    let compose_content = fs::read_to_string(&compose_file).unwrap_or_default();
    let is_gluetun_setup = compose_content.contains("qmcgaw/gluetun") || compose_content.contains("network_mode: \"service:vpn\"");
    
    // Determine container names based on setup type
    let (vpn_container, service_container) = if is_gluetun_setup {
        (Some(format!("playground-vpn-{}", language)), format!("playground-{}", language))
    } else if language.contains("-gluetun") {
        // For explicit gluetun services
        let base_service = language.replace("-gluetun", "");
        (Some(format!("playground-vpn-{}", base_service)), format!("playground-{}", base_service))
    } else {
        (None, format!("playground-{}", language))
    };
    
    // Check VPN container status if it exists
    if let Some(vpn_name) = &vpn_container {
        let output = Command::new("docker")
            .args(&["ps", "--filter", &format!("name={}", vpn_name), "--format", "table {{.Names}}\t{{.Status}}\t{{.Ports}}"])
            .output()
            .expect("Failed to run docker ps");
        
        let status_output = String::from_utf8_lossy(&output.stdout);
        println!("VPN Container Status:");
        println!("{}", status_output);
        
        if status_output.contains(vpn_name) {
            println!("Checking gluetun VPN status...");
            let health_output = Command::new("docker")
                .args(&["logs", "--tail", "20", vpn_name])
                .output();
                
            match health_output {
                Ok(output) => {
                    let logs = String::from_utf8_lossy(&output.stdout);
                    if logs.contains("VPN is up") || logs.contains("healthy") {
                        println!("✅ VPN connection is healthy");
                    } else {
                        println!("⚠️  VPN status unclear. Recent logs:");
                        println!("{}", logs);
                    }
                },
                Err(e) => println!("Failed to check VPN status: {}", e),
            }
        }
    }
    
    // Check service container status
    let output = Command::new("docker")
        .args(&["ps", "--filter", &format!("name={}", service_container), "--format", "table {{.Names}}\t{{.Status}}\t{{.Ports}}"])
        .output()
        .expect("Failed to run docker ps");
    
    let status_output = String::from_utf8_lossy(&output.stdout);
    println!("Service Container Status:");
    println!("{}", status_output);
    
    if !status_output.contains(&service_container) {
        println!("Container is not running. Start it with: doc start {}", language);
    }
}

fn test_functionality(root: &PathBuf, language: &str) {
    let supported_services = ["torrenting", "javascript"];
    if !supported_services.contains(&language) {
        eprintln!("\x1b[31mError:\x1b[0m Test functionality only available for: {}", supported_services.join(", "));
        std::process::exit(1);
    }
    
    println!("Testing {} functionality...", language);
    
    // Check if this is a gluetun-based setup by looking at the compose file
    let compose_file = root.join(language).join("docker-compose.yml");
    let compose_content = fs::read_to_string(&compose_file).unwrap_or_default();
    let is_gluetun_setup = compose_content.contains("qmcgaw/gluetun") || compose_content.contains("network_mode: \"service:vpn\"");
    
    let container_name = if is_gluetun_setup {
        // For gluetun setups, use the VPN container for testing
        format!("playground-vpn-{}", language)
    } else if language.contains("-gluetun") {
        // For gluetun setups, use the VPN container for testing
        let base_service = language.replace("-gluetun", "");
        format!("playground-vpn-{}", base_service)
    } else {
        format!("playground-{}", language)
    };
    
    // Test 1: Check if container is running
    println!("\n1. Checking if container is running...");
    let output = Command::new("docker")
        .args(&["ps", "-q", "--filter", &format!("name={}", container_name)])
        .output()
        .expect("Failed to run docker ps");
    
    if output.stdout.is_empty() {
        println!("❌ Container is not running. Start it with: doc start {}", language);
        return;
    }
    println!("✅ Container is running");
    
    // Test 2: Check VPN connection
    println!("\n2. Testing VPN connection...");
    if is_gluetun_setup || language.contains("-gluetun") {
        // For gluetun, check if VPN is up via logs
        let vpn_test = Command::new("docker")
            .args(&["logs", "--tail", "10", &container_name])
            .output();
        
        match vpn_test {
            Ok(output) => {
                let logs = String::from_utf8_lossy(&output.stdout);
                if logs.contains("VPN is up") || logs.contains("healthy") {
                    println!("✅ Gluetun VPN is connected");
                } else {
                    println!("⚠️  VPN status unclear from logs");
                }
            },
            Err(e) => println!("❌ Failed to check VPN logs: {}", e),
        }
    } else {
        // Original VPN check for non-gluetun setups
        let vpn_test = Command::new("docker")
            .args(&["exec", &container_name, "ip", "route", "show", "table", "main"])
            .output();
        
        match vpn_test {
            Ok(output) => {
                let routes = String::from_utf8_lossy(&output.stdout);
                if routes.contains("tun0") {
                    println!("✅ VPN interface (tun0) is active");
                } else {
                    println!("❌ VPN interface not found");
                    println!("Routes: {}", routes);
                }
            },
            Err(e) => println!("❌ Failed to check VPN: {}", e),
        }
    }
    
    // Test 3: Check external IP
    println!("\n3. Testing external IP through VPN...");
    if is_gluetun_setup || language.contains("-gluetun") {
        // For gluetun, just test external IP without specifying interface
        let ip_test = Command::new("docker")
            .args(&["exec", &container_name, "curl", "-s", "--max-time", "10", "https://ipinfo.io/ip"])
            .output();
        
        match ip_test {
            Ok(output) => {
                if output.status.success() {
                    let ip_response = String::from_utf8_lossy(&output.stdout);
                    println!("✅ External IP via Gluetun: {}", ip_response.trim());
                } else {
                    println!("❌ Failed to get external IP through Gluetun VPN");
                }
            },
            Err(e) => println!("❌ Failed to test external IP: {}", e),
        }
    } else {
        // Original test for non-gluetun setups
        let ip_test = Command::new("docker")
            .args(&["exec", &container_name, "curl", "-s", "--max-time", "10", "--interface", "tun0", "https://httpbin.org/ip"])
            .output();
        
        match ip_test {
            Ok(output) => {
                if output.status.success() {
                    let ip_response = String::from_utf8_lossy(&output.stdout);
                    println!("✅ External IP via VPN: {}", ip_response);
                } else {
                    println!("❌ Failed to get external IP through VPN");
                }
            },
            Err(e) => println!("❌ Failed to test external IP: {}", e),
        }
    }
    
    // Service-specific tests
    match language {
        "torrenting" => {
            // Test 4: Check qBittorrent Web UI
            println!("\n4. Testing qBittorrent Web UI...");
            let ui_test = Command::new("curl")
                .args(&["-s", "--max-time", "5", "http://localhost:8081"])
                .output();
            
            match ui_test {
                Ok(output) => {
                    if output.status.success() {
                        println!("✅ qBittorrent Web UI is accessible at http://localhost:8081");
                    } else {
                        println!("❌ qBittorrent Web UI is not accessible");
                    }
                },
                Err(e) => println!("❌ Failed to test Web UI: {}", e),
            }
            
            // Test 5: Check download directory
            println!("\n5. Checking download directory...");
            let downloads_dir = root.join(language).join("data").join("downloads");
            if downloads_dir.exists() {
                println!("✅ Downloads directory exists: {}", downloads_dir.display());
                match fs::metadata(&downloads_dir) {
                    Ok(metadata) => {
                        if metadata.is_dir() {
                            println!("✅ Downloads directory is accessible");
                        } else {
                            println!("❌ Downloads path is not a directory");
                        }
                    },
                    Err(e) => println!("❌ Failed to check downloads directory: {}", e),
                }
            } else {
                println!("❌ Downloads directory not found: {}", downloads_dir.display());
            }
        },
        "javascript" | "javascript-gluetun" => {
            // Test 4: Check development ports
            println!("\n4. Testing development server ports...");
            let ports = [3000, 5173, 8080];
            let mut accessible_ports = Vec::new();
            
            for port in ports {
                let port_test = Command::new("curl")
                    .args(&["-s", "--max-time", "3", &format!("http://localhost:{}", port)])
                    .output();
                
                if let Ok(output) = port_test {
                    if output.status.success() {
                        accessible_ports.push(port);
                    }
                }
            }
            
            if accessible_ports.is_empty() {
                println!("ℹ️  No development servers currently running");
            } else {
                println!("✅ Development servers accessible on ports: {:?}", accessible_ports);
            }
            
            // Test 5: Check project directory
            println!("\n5. Checking project directory...");
            let data_dir = root.join(language).join("data");
            if data_dir.exists() {
                println!("✅ Data directory exists: {}", data_dir.display());
            } else {
                println!("ℹ️  Data directory not found (will be created on first use)");
            }
            
            // Test 6: Check snublejuice access
            println!("\n6. Checking snublejuice code access...");
            let test_container = if is_gluetun_setup {
                format!("playground-{}", language)
            } else {
                container_name.clone()
            };
            let snublejuice_test = Command::new("docker")
                .args(&["exec", &test_container, "ls", "-la", "/home/snublejuice"])
                .output();
            
            match snublejuice_test {
                Ok(output) => {
                    if output.status.success() {
                        println!("✅ Snublejuice code is accessible");
                    } else {
                        println!("❌ Snublejuice code access failed");
                    }
                },
                Err(e) => println!("❌ Failed to test snublejuice access: {}", e),
            }
        },
        _ => {}
    }
    
    println!("\nTest complete! If all tests pass, your {} setup should be working correctly.", language);
}
