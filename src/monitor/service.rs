use anyhow::Result;
use std::sync::{Arc, atomic::{AtomicBool, Ordering}};
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use tokio::time::sleep;
use std::collections::HashMap;
use reqwest::StatusCode;
use std::process::Command;
use std::path::PathBuf;

use crate::monitor::db::{get_all_sites, update_site_status};
use crate::monitor::notifier::{send_notification, log_notification_attempt};
use crate::utils::get_status_description;
use crate::monitor::db::get_site_by_url;

// Global state to track if the service is running
static SERVICE_RUNNING: AtomicBool = AtomicBool::new(false);
// Global state to track if the service should stop
static SERVICE_SHOULD_STOP: AtomicBool = AtomicBool::new(false);

// Get the path to the daemon executable
fn get_daemon_path() -> PathBuf {
    std::env::current_exe().unwrap_or_else(|_| "isup".into())
}

// Start the background service as a separate process
pub fn start_background_service() -> Result<()> {
    // Check if daemon is already running
    if is_daemon_running() {
        println!("monitoring service (daemon) is already running");
        return Ok(());
    }
    
    // Clean up any stale PID file before starting
    #[cfg(target_family = "unix")]
    {
        let _ = std::fs::remove_file("/tmp/isup_daemon.pid");
    }
    
    println!("starting monitoring service...");
    
    // Start the daemon process
    let daemon_path = get_daemon_path();
    
    #[cfg(target_family = "unix")]
    {
        // Use a more reliable approach with explicit output redirection
        let cmd = format!(
            "DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{}/bus nohup \"{}\" daemon > /tmp/isup_daemon.log 2>&1 & echo $! > /tmp/isup_daemon.pid",
            std::process::id(),
            daemon_path.display()
        );
        
        let status = Command::new("sh")
            .arg("-c")
            .arg(&cmd)
            .status()?;
            
        if !status.success() {
            return Err(anyhow::anyhow!("failed to start monitoring daemon"));
        }
        
        // Wait briefly for the process to start
        std::thread::sleep(Duration::from_millis(1000));
        
        // Read the PID file to confirm the process started
        match std::fs::read_to_string("/tmp/isup_daemon.pid") {
            Ok(pid_str) => {
                if let Ok(pid) = pid_str.trim().parse::<u32>() {
                    // Verify the process is actually running
                    if is_daemon_running() {
                        println!("monitoring daemon started with PID: {}", pid);
                    } else {
                        return Err(anyhow::anyhow!("daemon process failed to start properly"));
                    }
                } else {
                    return Err(anyhow::anyhow!("invalid PID in daemon PID file"));
                }
            },
            Err(_) => {
                return Err(anyhow::anyhow!("failed to read daemon PID file"));
            }
        }
    }
    
    #[cfg(target_family = "windows")]
    {
        // More reliable Windows implementation
        let status = Command::new("cmd")
            .args(&[
                "/C", 
                "start", 
                "/B", 
                &format!("\"ISUP Monitor\""), 
                daemon_path.to_str().unwrap(), 
                "daemon", 
                ">", 
                "%TEMP%\\isup_daemon.log", 
                "2>&1"
            ])
            .status()?;
            
        if !status.success() {
            return Err(anyhow::anyhow!("failed to start monitoring daemon"));
        }
    }
    
    // Wait a moment to see if the daemon starts successfully
    std::thread::sleep(Duration::from_millis(500));
    
    if is_daemon_running() {
        println!("✅ monitoring service started successfully");
    } else {
        println!("⚠️ monitoring service may not have started properly");
        println!("   Check logs at /tmp/isup_daemon.log for details");
    }
    
    Ok(())
}

// Add a new function to check if the daemon is running
pub fn is_daemon_running() -> bool {
    #[cfg(target_family = "unix")]
    {
        // Try to read the PID file and check if process exists
        if let Ok(pid_str) = std::fs::read_to_string("/tmp/isup_daemon.pid") {
            if let Ok(pid) = pid_str.trim().parse::<u32>() {
                // On Unix, check if process exists using kill -0
                let exists = Command::new("kill")
                    .args(&["-0", &pid.to_string()])
                    .status()
                    .map(|status| status.success())
                    .unwrap_or(false);
                
                if !exists {
                    // Clean up stale PID file if process doesn't exist
                    let _ = std::fs::remove_file("/tmp/isup_daemon.pid");
                }
                return exists;
            }
        }
        // Clean up PID file if it's invalid
        let _ = std::fs::remove_file("/tmp/isup_daemon.pid");
        false
    }
    
    #[cfg(target_family = "windows")]
    {
        // On Windows, check using tasklist
        Command::new("tasklist")
            .args(&["/FI", "IMAGENAME eq isup.exe", "/NH"])
            .output()
            .map(|output| {
                let output_str = String::from_utf8_lossy(&output.stdout);
                output_str.contains("isup.exe")
            })
            .unwrap_or(false)
    }
}

// Function to stop the monitoring service
pub fn stop_monitoring_service() -> Result<()> {
    if !is_daemon_running() {
        println!("monitoring service is not running");
        return Ok(());
    }
    
    #[cfg(target_family = "unix")]
    {
        if let Ok(pid_str) = std::fs::read_to_string("/tmp/isup_daemon.pid") {
            if let Ok(pid) = pid_str.trim().parse::<u32>() {
                // Set the global flag to stop the service
                SERVICE_SHOULD_STOP.store(true, Ordering::SeqCst);
                
                // Send SIGTERM to gracefully terminate the process
                let status = Command::new("kill")
                    .arg(pid.to_string())
                    .status()?;
                
                if status.success() {
                    // Wait a moment for the service to clean up
                    std::thread::sleep(Duration::from_millis(500));
                    
                    // Check if the process is still running
                    if !is_daemon_running() {
                        println!("✅ monitoring service stopped successfully");
                        
                        // Clean up the PID file
                        let _ = std::fs::remove_file("/tmp/isup_daemon.pid");
                        return Ok(());
                    } else {
                        // If still running, try a more forceful approach
                        println!("service still running, attempting forceful termination...");
                        let force_status = Command::new("kill")
                            .args(&["-9", &pid.to_string()])
                            .status()?;
                            
                        if force_status.success() {
                            // Wait a moment to ensure process is terminated
                            std::thread::sleep(Duration::from_millis(300));
                            
                            if !is_daemon_running() {
                                println!("✅ monitoring service stopped successfully");
                                let _ = std::fs::remove_file("/tmp/isup_daemon.pid");
                                return Ok(());
                            }
                        }
                    }
                }
                
                return Err(anyhow::anyhow!("failed to stop monitoring service, you may need to terminate it manually"));
            }
        }
        
        Err(anyhow::anyhow!("could not read PID file"))
    }
    
    #[cfg(target_family = "windows")]
    {
        // On Windows, use taskkill
        let status = Command::new("taskkill")
            .args(&["/F", "/IM", "isup.exe", "/T"])
            .status()?;
            
        if status.success() {
            println!("✅ monitoring service stopped successfully");
            return Ok(());
        } else {
            return Err(anyhow::anyhow!("failed to stop monitoring service"));
        }
    }
}

// This function runs the monitoring service - this is the one referenced in main.rs
pub fn run_monitor_service() -> Result<()> {
    // Set the service as running
    SERVICE_RUNNING.store(true, Ordering::SeqCst);
    SERVICE_SHOULD_STOP.store(false, Ordering::SeqCst);
    
    // Create a file to store the PID for management
    #[cfg(target_family = "unix")]
    {
        let pid = std::process::id();
        let _ = std::fs::write("/tmp/isup_daemon.pid", pid.to_string());
    }
    
    // Build a minimal runtime for efficiency
    let runtime = tokio::runtime::Builder::new_current_thread()
        .worker_threads(1) // Use just one worker thread to minimize resource usage
        .enable_io()
        .enable_time()
        .build()?;
    
    println!("monitoring service started successfully");
    
    // Run the service with signal handling
    runtime.block_on(async {
        // Set up signal handlers
        #[cfg(target_family = "unix")]
        {
            let mut term_signal = signal(SignalKind::terminate())
                .expect("failed to create SIGTERM handler");
            let mut int_signal = signal(SignalKind::interrupt())
                .expect("failed to create SIGINT handler");
            
            // Spawn a task to handle termination signals
            tokio::spawn(async move {
                tokio::select! {
                    _ = term_signal.recv() => {
                        println!("received SIGTERM signal");
                        SERVICE_SHOULD_STOP.store(true, Ordering::SeqCst);
                    }
                    _ = int_signal.recv() => {
                        println!("received SIGINT signal");
                        SERVICE_SHOULD_STOP.store(true, Ordering::SeqCst);
                    }
                }
            });
        }
        
        // The main monitoring loop
        monitor_sites_loop().await
    })?;
    
    // Clean up
    #[cfg(target_family = "unix")]
    {
        let _ = std::fs::remove_file("/tmp/isup_daemon.pid");
    }
    
    // Service is no longer running
    SERVICE_RUNNING.store(false, Ordering::SeqCst);
    
    Ok(())
}

// The main monitoring loop
async fn monitor_sites_loop() -> Result<()> {
    // Create a shared HTTP client
    let client = reqwest::Client::builder()
        .user_agent("isup/0.1.0")
        .timeout(Duration::from_secs(10))
        .build()?;
    
    // Track the next check time for each site
    let next_checks: Arc<Mutex<HashMap<String, Instant>>> = Arc::new(Mutex::new(HashMap::new()));
    
    println!("starting monitoring loop");
    
    // Main loop
    loop {
        // Check if we should stop
        if SERVICE_SHOULD_STOP.load(Ordering::SeqCst) {
            println!("stopping monitoring service due to stop request");
            return Ok(());
        }
        
        // Get all sites from the database
        let sites = match get_all_sites() {
            Ok(sites) => sites,
            Err(e) => {
                eprintln!("🚨 error fetching sites: {}", e);
                sleep(Duration::from_secs(5)).await;
                continue;
            }
        };
        
        if sites.is_empty() {
            // No sites to monitor, sleep for a bit and check again
            sleep(Duration::from_secs(5)).await;
            continue;
        }
        
        // Process each site
        for site in sites {
            let url = site.url.clone();
            let interval = site.interval;
            
            let mut next_checks_map = next_checks.lock().await;
            let now = Instant::now();
            
            // Check if it's time to check this site
            let should_check = match next_checks_map.get(&url) {
                Some(next_time) if *next_time > now => false,
                _ => true,
            };
            
            if should_check {
                // Schedule the next check
                next_checks_map.insert(
                    url.clone(),
                    now + Duration::from_secs_f64(interval)
                );
                
                // Clone what we need for the task
                let url_clone = url.clone();
                let client_clone = client.clone();
                
                // Spawn a task to check the site
                tokio::spawn(async move {
                    println!("🔄 checking site: {}", url_clone);
                    
                    match check_site(&client_clone, &url_clone).await {
                        Ok((status, is_success)) => {
                            let status_code = status.as_u16();
                            let status_desc = get_status_description(status_code);
                            let status_text = format!("{} - {}", status_code, status_desc);
                            
                            // Get the current site status BEFORE updating it
                            let previous_status = match get_site_by_url(&url_clone) {
                                Ok(Some(site)) => site.is_up,
                                _ => None
                            };
                            
                            // Determine if this is a state change that requires notification
                            let state_changed = match previous_status {
                                Some(was_up) => was_up != is_success,
                                None => false // For first check, don't notify
                            };
                            
                            // Log the status check
                            println!("🔄 site {} status: {} ({}), previous status: {:?}, state changed: {}", 
                                url_clone, 
                                if is_success { "UP" } else { "DOWN" }, 
                                status_text,
                                previous_status,
                                state_changed);
                            
                            // Update the site status in the database
                            if let Err(e) = update_site_status(&url_clone, is_success, &status_desc) {
                                eprintln!("Failed to update site status: {}", e);
                            }
                            
                            // Send notification if state changed
                            if state_changed {
                                println!("🔄 state change detected for {}: was {:?}, now {}", 
                                    url_clone, 
                                    previous_status, 
                                    if is_success { "UP" } else { "DOWN" });
                                
                                // Extract just the hostname from URL for cleaner notifications
                                let site_name = extract_hostname(&url_clone);
                                
                                // Send a single notification with simplified content
                                let notification_result = send_notification(
                                    &site_name,
                                    !is_success,
                                    &status_desc
                                );
                                
                                // Log whether notification was successful
                                log_notification_attempt(
                                    &url_clone, 
                                    !is_success, 
                                    &status_desc,
                                    &notification_result
                                );
                            }
                        },
                        Err(e) => {
                            println!("🚨 site check failed for {}: {}", url_clone, e);
                            
                            // Get the current site status BEFORE updating it
                            let previous_status = match get_site_by_url(&url_clone) {
                                Ok(Some(site)) => site.is_up,
                                _ => None
                            };
                            
                            // Determine if this is a state change that requires notification
                            let state_changed = match previous_status {
                                Some(was_up) => was_up, // If it was up before, we need to notify
                                None => false // For first check, don't notify
                            };
                            
                            // Get a generic error status description
                            let status_desc = get_status_description(503); // Service Unavailable
                            
                            // Site is down due to connection error
                            if let Err(db_err) = update_site_status(&url_clone, false, &status_desc) {
                                eprintln!("Failed to update site status: {}", db_err);
                            }
                            
                            // Send notification if state changed
                            if state_changed {
                                println!("🔄 state change detected for {}: was {:?}, now DOWN (error)", 
                                    url_clone, 
                                    previous_status);
                                
                                // Extract just the hostname from URL for cleaner notifications
                                let site_name = extract_hostname(&url_clone);
                                
                                // Send a single notification with simplified content
                                let notification_result = send_notification(
                                    &site_name,
                                    true,
                                    &status_desc
                                );
                                
                                // Log whether notification was successful
                                log_notification_attempt(
                                    &url_clone, 
                                    true, 
                                    &status_desc,
                                    &notification_result
                                );
                            }
                        }
                    }
                });
            }
        }
        
        // Sleep for a short time before the next iteration
        // This makes the loop responsive while using minimal resources
        sleep(Duration::from_millis(100)).await;
    }
}

// Helper function to extract the hostname from a URL
fn extract_hostname(url: &str) -> String {
    // Remove protocol (http:// or https://)
    let without_protocol = url.trim_start_matches("http://").trim_start_matches("https://");
    
    // Extract domain (everything up to the first / or the entire string if no /)
    let domain = match without_protocol.find('/') {
        Some(pos) => &without_protocol[..pos],
        None => without_protocol,
    };
    
    // Remove www. prefix if present
    let hostname = domain.trim_start_matches("www.");
    
    hostname.to_string()
}

// Check a single site
async fn check_site(client: &reqwest::Client, url: &str) -> Result<(StatusCode, bool)> {
    let response = client.get(url).send().await?;
    let status = response.status();
    let is_success = status.is_success();
    
    Ok((status, is_success))
}

// Add platform-specific signal handling
#[cfg(unix)]
use tokio::signal::unix::{signal, SignalKind};

#[cfg(windows)]
use tokio::signal::windows::ctrl_c;

// Then wherever you're using the signal handling, wrap it in platform-specific code:
#[cfg(unix)]
async fn handle_shutdown_signals() {
    let mut sigterm = signal(SignalKind::terminate()).unwrap();
    let mut sigint = signal(SignalKind::interrupt()).unwrap();
    tokio::select! {
        _ = sigterm.recv() => {},
        _ = sigint.recv() => {},
    }
}

#[cfg(windows)]
async fn handle_shutdown_signals() {
    let mut ctrlc = ctrl_c().unwrap();
    ctrlc.recv().await;
} 