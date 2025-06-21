use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;

use dirs;
use clap::{Parser, Subcommand};

const CONFIG_FILE: &str = ".docconfig";

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
    /// Setup project root and VPN configuration for services
    Setup { 
        /// Service to setup (torrenting, javascript, or skip for project root only)
        #[arg(value_name = "SERVICE")]
        service: Option<String> 
    },
    /// Check container status and VPN connection
    Status { language: String },
    /// Test VPN and service functionality
    Test { language: String },
    /// Verify VPN connection is working
    VpnCheck { language: String },
    /// Verify killswitch is properly configured
    KillswitchCheck { language: String },
}

#[cfg(target_os = "windows")]
fn execute_script_windows(script_path: &PathBuf, service_name: &str, project_root: &PathBuf, root: &PathBuf) -> std::process::ExitStatus {
    // Try Git Bash first (most reliable on Windows)
    println!("Attempting to run script via Git Bash...");
    let git_bash_paths = [
        "C:\\Program Files\\Git\\bin\\bash.exe",
        "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
        "bash.exe", // If it's in PATH
    ];
    
    for bash_path in &git_bash_paths {
        let git_bash_result = Command::new(bash_path)
            .arg(script_path)
            .arg(service_name)
            .arg(project_root)
            .current_dir(root)
            .status();
            
        if let Ok(status) = git_bash_result {
            return status;
        }
    }
    
    // Try WSL as fallback (if available and properly configured)
    println!("Git Bash not found, trying WSL...");
    let script_unix_path = format!("/{}", script_path.to_string_lossy().replace(":\\", "/").replace("\\", "/"));
    let project_root_unix_path = format!("/{}", project_root.to_string_lossy().replace(":\\", "/").replace("\\", "/"));
    let root_unix_path = format!("/{}", root.to_string_lossy().replace(":\\", "/").replace("\\", "/"));
    
    let wsl_result = Command::new("wsl")
        .arg("bash")
        .arg("-c")
        .arg(&format!("cd '{}' && bash '{}' '{}' '{}'", 
                     root_unix_path,
                     script_unix_path,
                     service_name, 
                     project_root_unix_path))
        .status();
    
    if let Ok(status) = wsl_result {
        return status;
    }
    
    // Final fallback: PowerShell with WSL
    println!("WSL direct execution failed, trying PowerShell + WSL...");
    let ps_command = format!(
        "wsl bash -c \"cd '{}' && bash '{}' '{}' '{}'\"",
        root_unix_path,
        script_unix_path,
        service_name,
        project_root_unix_path
    );
    
    let ps_result = Command::new("powershell")
        .arg("-Command")
        .arg(&ps_command)
        .status();
        
    match ps_result {
        Ok(status) => status,
        Err(_) => {
            eprintln!("\x1b[31mError:\x1b[0m Failed to execute VPN setup script on Windows.");
            eprintln!("Please ensure one of the following is available:");
            eprintln!("  - Git Bash (recommended)");
            eprintln!("  - WSL (Windows Subsystem for Linux) with bash installed");
            eprintln!("\nAlternatively, you can run the setup script manually:");
            eprintln!("  bash \"{}\" {} \"{}\"", script_path.display(), service_name, project_root.display());
            std::process::exit(1);
        }
    }
}

fn main() {
    let cli = Cli::parse();
    match &cli.command {
        Commands::Setup { service } => {
            let root = resolve_root(cli.root.as_ref());
            setup_project_and_service(&root, service.as_deref());
            return;
        }
        Commands::Status { language } => {
            check_status(&resolve_root(cli.root.as_ref()), language);
            return;
        }
        Commands::Test { language } => {
            test_functionality(&resolve_root(cli.root.as_ref()), language);
            return;
        }
        Commands::VpnCheck { language } => {
            check_vpn_connection(&resolve_root(cli.root.as_ref()), language);
            return;
        }
        Commands::KillswitchCheck { language } => {
            check_killswitch(&resolve_root(cli.root.as_ref()), language);
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
        Commands::Setup { .. } => unreachable!(),
        Commands::Status { .. } => unreachable!(),
        Commands::Test { .. } => unreachable!(),
        Commands::VpnCheck { .. } => unreachable!(),
        Commands::KillswitchCheck { .. } => unreachable!(),
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

fn setup_project_and_service(root: &PathBuf, service: Option<&str>) {
    // First, check if project root is properly configured
    // We need to check if the config file exists and contains a valid path
    let is_configured = if let Some(home) = dirs::home_dir() {
        let config_path = home.join(CONFIG_FILE);
        if let Ok(path) = fs::read_to_string(&config_path) {
            let trimmed = path.trim();
            !trimmed.is_empty() && Path::new(trimmed).exists() && Path::new(trimmed).is_dir()
        } else {
            false
        }
    } else {
        false
    };
    
    if !is_configured {
        setup_project_root();
        // After setup, we need to resolve the root again to get the newly configured path
        let new_root = resolve_root(None);
        // Recursively call ourselves with the new root
        setup_project_and_service(&new_root, service);
        return;
    }
    
    // If no service specified, just setup project root
    if service.is_none() {
        println!("Project root setup complete!");
        println!("To setup a service, run: doc setup [torrenting|javascript]");
        return;
    }
    
    let service_name = service.unwrap();
    
    // Validate service
    match service_name {
        "torrenting" | "javascript" => {},
        _ => {
            eprintln!("\x1b[31mError:\x1b[0m Unsupported service: {}. Use 'torrenting' or 'javascript'.", service_name);
            std::process::exit(1);
        }
    }
    
    // Check if service directory exists
    let service_dir = root.join(service_name);
    if !service_dir.exists() {
        eprintln!("\x1b[31mError:\x1b[0m Service directory not found: {}", service_dir.display());
        std::process::exit(1);
    }
    
    println!("Setting up {} service with VPN...", service_name);
    
    // Create service data directory
    let data_dir = service_dir.join("data");
    if let Err(e) = fs::create_dir_all(&data_dir) {
        eprintln!("\x1b[31mError:\x1b[0m Failed to create data directory: {}", e);
        std::process::exit(1);
    }
    
    // Create common VPN config directory
    let vpn_config_dir = root.join("vpn").join("config");
    if let Err(e) = fs::create_dir_all(&vpn_config_dir) {
        eprintln!("\x1b[31mError:\x1b[0m Failed to create VPN config directory: {}", e);
        std::process::exit(1);
    }
    
    // Run the unified VPN setup script
    let vpn_setup_script = root.join("vpn").join("scripts").join("setup-vpn.sh");
    if !vpn_setup_script.exists() {
        eprintln!("\x1b[31mError:\x1b[0m VPN setup script not found: {}", vpn_setup_script.display());
        eprintln!("Make sure the vpn directory is present in your project root.");
        std::process::exit(1);
    }
    
    println!("Running VPN setup script...");
    
    // Cross-platform script execution
    let status = if cfg!(target_os = "windows") {
        // On Windows, try multiple approaches
        execute_script_windows(&vpn_setup_script, service_name, root, root)
    } else {
        // On Unix-like systems, use bash directly
        Command::new("bash")
            .arg(&vpn_setup_script)
            .arg(service_name)
            .arg(root)
            .current_dir(root)
            .status()
            .expect("Failed to run VPN setup script")
    };
    
    if !status.success() {
        eprintln!("\x1b[31mError:\x1b[0m VPN setup failed");
        std::process::exit(1);
    }
    
    println!("\n✅ {} service setup complete!", service_name);
    println!("Next steps:");
    println!("  - doc start {}", service_name);
    println!("  - doc status {}", service_name);
    println!("  - doc test {}", service_name);
}

fn setup_project_root() {
    println!("Setting up project root...");
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
        println!("✅ Project root saved to {}", config_path.display());
    } else {
        eprintln!("\x1b[31mError:\x1b[0m Could not determine home directory.");
        std::process::exit(1);
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
    
    // Check if container is running
    let container_name = format!("playground-{}", language);
    let output = Command::new("docker")
        .args(&["ps", "--filter", &format!("name={}", container_name), "--format", "table {{.Names}}\t{{.Status}}\t{{.Ports}}"])
        .output()
        .expect("Failed to run docker ps");
    
    let status_output = String::from_utf8_lossy(&output.stdout);
    println!("Container Status:");
    println!("{}", status_output);
    
    if status_output.contains(&container_name) {
        println!("\nRunning health check...");
        let health_output = Command::new("docker")
            .args(&["exec", &container_name, "/usr/local/bin/health-check.sh", language])
            .output();
            
        match health_output {
            Ok(output) => {
                let health_result = String::from_utf8_lossy(&output.stdout);
                println!("{}", health_result);
                if !output.status.success() {
                    let error_result = String::from_utf8_lossy(&output.stderr);
                    println!("Health check errors: {}", error_result);
                }
            },
            Err(e) => println!("Failed to run health check: {}", e),
        }
    } else {
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
    
    let container_name = format!("playground-{}", language);
    
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
    
    // Test 3: Check external IP
    println!("\n3. Testing external IP through VPN...");
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
            let downloads_dir = root.join("torrenting").join("data").join("downloads");
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
        "javascript" => {
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
            let projects_dir = root.join("javascript").join("data").join("projects");
            if projects_dir.exists() {
                println!("✅ Projects directory exists: {}", projects_dir.display());
            } else {
                println!("ℹ️  Projects directory not found (will be created on first use)");
            }
        },
        _ => {}
    }
    
    println!("\nTest complete! If all tests pass, your {} setup should be working correctly.", language);
}

fn check_vpn_connection(_root: &PathBuf, language: &str) {
    let supported_services = ["torrenting", "javascript"];
    if !supported_services.contains(&language) {
        eprintln!("\x1b[31mError:\x1b[0m VPN check only available for: {}", supported_services.join(", "));
        std::process::exit(1);
    }
    
    println!("Checking VPN connection for {} service...", language);
    
    let container_name = format!("playground-{}", language);
    
    // Check if container is running
    let output = Command::new("docker")
        .args(&["ps", "-q", "--filter", &format!("name={}", container_name)])
        .output()
        .expect("Failed to run docker ps");
    
    if output.stdout.is_empty() {
        println!("❌ Container is not running. Start it with: doc start {}", language);
        return;
    }
    
    // Run health check
    let health_output = Command::new("docker")
        .args(&["exec", &container_name, "/usr/local/bin/health-check.sh", language])
        .output();
        
    match health_output {
        Ok(output) => {
            let health_result = String::from_utf8_lossy(&output.stdout);
            println!("{}", health_result);
            if !output.status.success() {
                let error_result = String::from_utf8_lossy(&output.stderr);
                println!("VPN check errors: {}", error_result);
                std::process::exit(1);
            }
        },
        Err(e) => {
            println!("❌ Failed to run VPN check: {}", e);
            std::process::exit(1);
        }
    }
}

fn check_killswitch(_root: &PathBuf, language: &str) {
    let supported_services = ["torrenting", "javascript"];
    if !supported_services.contains(&language) {
        eprintln!("\x1b[31mError:\x1b[0m Killswitch check only available for: {}", supported_services.join(", "));
        std::process::exit(1);
    }
    
    println!("Checking killswitch configuration for {} service...", language);
    
    let container_name = format!("playground-{}", language);
    
    // Check if container is running
    let output = Command::new("docker")
        .args(&["ps", "-q", "--filter", &format!("name={}", container_name)])
        .output()
        .expect("Failed to run docker ps");
    
    if output.stdout.is_empty() {
        println!("❌ Container is not running. Start it with: doc start {}", language);
        return;
    }
    
    // Check iptables rules
    println!("Checking iptables rules...");
    let iptables_output = Command::new("docker")
        .args(&["exec", &container_name, "iptables", "-L", "-n", "-v"])
        .output();
        
    match iptables_output {
        Ok(output) => {
            let rules = String::from_utf8_lossy(&output.stdout);
            
            // Check for key killswitch indicators
            let has_drop_policy = rules.contains("policy DROP");
            let has_tun_rules = rules.contains("tun");
            let has_vpn_rules = rules.contains("1194") || rules.contains("443");
            
            if has_drop_policy {
                println!("✅ Default DROP policy is active");
            } else {
                println!("❌ Default DROP policy not found");
            }
            
            if has_tun_rules {
                println!("✅ VPN tunnel interface rules are configured");
            } else {
                println!("❌ VPN tunnel interface rules not found");
            }
            
            if has_vpn_rules {
                println!("✅ VPN connection rules are configured");
            } else {
                println!("❌ VPN connection rules not found");
            }
            
            // Test that traffic is blocked without VPN
            println!("\nTesting traffic blocking without VPN interface...");
            let leak_test = Command::new("docker")
                .args(&["exec", &container_name, "bash", "-c", "timeout 5 curl -s --interface eth0 https://httpbin.org/ip 2>/dev/null || echo 'BLOCKED'"])
                .output();
                
            match leak_test {
                Ok(output) => {
                    let result = String::from_utf8_lossy(&output.stdout);
                    if result.contains("BLOCKED") || result.trim().is_empty() {
                        println!("✅ Traffic properly blocked without VPN");
                    } else {
                        println!("❌ Traffic leakage detected: {}", result);
                    }
                },
                Err(e) => println!("❌ Failed to test traffic blocking: {}", e),
            }
            
            if has_drop_policy && has_tun_rules && has_vpn_rules {
                println!("\n✅ Killswitch is properly configured");
            } else {
                println!("\n❌ Killswitch configuration issues detected");
                std::process::exit(1);
            }
        },
        Err(e) => {
            println!("❌ Failed to check iptables rules: {}", e);
            std::process::exit(1);
        }
    }
}
