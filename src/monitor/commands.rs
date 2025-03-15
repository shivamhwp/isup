use anyhow:: Result;
use colored::*;
use std::time::{SystemTime, UNIX_EPOCH};

use crate::monitor::db::{add_site_to_db, get_all_sites, get_site_by_url, remove_site_from_db, Site};
use crate::monitor::service::{start_background_service, is_daemon_running};

pub fn add_site(
    url: &str, 
    interval: f64, 
    notify: &str
) -> Result<()> {
    // Ensure URL has a scheme
    let url = if !url.starts_with("http://") && !url.starts_with("https://") {
        format!("https://{}", url)
    } else {
        url.to_string()
    };
    
    // Check if site already exists
    if get_site_by_url(&url)?.is_some() {
        println!("{} is already being monitored", url.cyan());
        return Ok(());
    }
    
    // Validate notification method
    if notify != "device" {
        println!("Note: Currently only device notifications are supported.");
    }
    
    // Create the site record
    let site = Site {
        id: None,
        url: url.clone(),
        interval,
        notify_method: "device".to_string(), // Always use device notifications
        is_up: None,
        last_checked: None,
        last_status: None,
        downtime_started: None,
    };
    
    // Add to database
    add_site_to_db(&site)?;
    
    println!("{} {} to monitoring with {} second interval", 
        "Added".green().bold(), 
        url.cyan(),
        interval.to_string().yellow());
    
    // Ensure the background service is running
    ensure_monitoring_service_running()?;
    
    Ok(())
}

pub fn list_sites() -> Result<()> {
    let sites = get_all_sites()?;
    
    if sites.is_empty() {
        println!("\n{}", "no sites are currently being monitored".yellow());
        return Ok(());
    }
    
    // Check if daemon is running for status indicator
    let daemon_running = is_daemon_running();
    
    if !daemon_running {
        println!("\n{}  monitoring service is not running. no sites are being checked.", "⚠️".yellow());
        println!("   run 'isup add' to restart the monitoring service.");
    } else {
        println!("\n{}  monitoring service is running.", "✓".green());
    }
    
    // Store the count before consuming the sites
    let site_count = sites.len();
    
    // Print header
    println!("📊 {} site(s) monitored by isup:", site_count);
    println!("{}", "─".repeat(70));
    println!("{:<40} {:<15} {:<15}", 
        "URL".bold(), 
        "STATUS".bold(), 
        "INTERVAL".bold());
    println!("{}", "─".repeat(70));
    
    // Print each site with spacing between them
    for (i, site) in sites.into_iter().enumerate() {
        let status = match site.is_up {
            Some(true) => "UP".green().bold(),
            Some(false) => "DOWN".red().bold(),
            None => "UNKNOWN".yellow().bold(),
        };
        
        println!("{:<40} {:<15} {:<15}\n", 
            site.url.cyan(),
            status,
            format!("{}s", site.interval));
            
    }
    
    Ok(())
}

pub fn remove_site(url: &str) -> Result<()> {
    // Ensure URL has a scheme
    let url = if !url.starts_with("http://") && !url.starts_with("https://") {
        format!("https://{}", url)
    } else {
        url.to_string()
    };
    
    // Check if site exists before attempting to remove
    let site_exists = get_site_by_url(&url)?.is_some();
    
    if !site_exists {
        println!("{} is not being monitored", url.cyan());
        return Ok(());
    }
    
    // Remove from database
    if remove_site_from_db(&url)? {
        println!("{} {} from monitoring", "Removed".green().bold(), url.cyan());
        
        // Verify the site was actually removed
        if get_site_by_url(&url)?.is_none() {
            println!("✅ Site successfully removed from database");
        } else {
            println!("⚠️ Site may still be in the database. Please try again.");
        }
    } else {
        println!("⚠️ Failed to remove {} from monitoring", url.cyan());
    }
    
    Ok(())
}

pub fn status_sites() -> Result<()> {
    let sites = get_all_sites()?;
    
    if sites.is_empty() {
        println!("{}", "no sites are currently being monitored".yellow());
        return Ok(());
    }
    
    // Check if daemon is running for status indicator
    let daemon_running = is_daemon_running();
    
    if !daemon_running {
        println!("{}  monitoring service is not running. no sites are being checked.", "⚠️".yellow());
        println!("   run 'isup add' to restart the monitoring service.");
    } else {
        println!("\n{}  monitoring service is running.", "✓".green());
    }    
    
    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
    
    // Print header without extra newline
    println!("📊 current status of monitored sites:");
    println!("{}", "─".repeat(95));
    println!("{:<40} {:<15} {:<20} {:<20}", 
        "URL".bold(), 
        "STATUS".bold(), 
        "LAST CHECKED".bold(), 
        "DOWNTIME".bold());
    println!("{}", "─".repeat(95));
    
    // Print each site status with spacing between them
    for (_i, site) in sites.iter().enumerate() {
        let status = match site.is_up {
            Some(true) => "UP".green().bold(),
            Some(false) => "DOWN".red().bold(),
            None => "UNKNOWN".yellow().bold(),
        };
        
        let last_checked = match site.last_checked {
            Some(timestamp) => {
                let ago = now - timestamp;
                if ago < 60 {
                    format!("{} seconds ago", ago)
                } else if ago < 3600 {
                    format!("{} minutes ago", ago / 60)
                } else {
                    format!("{} hours ago", ago / 3600)
                }
            },
            None => "Never".to_string(),
        };
        
        let downtime = match (site.is_up, site.downtime_started) {
            (Some(false), Some(start)) => {
                let duration = now - start;
                if duration < 60 {
                    format!("{} seconds", duration)
                } else if duration < 3600 {
                    format!("{} minutes", duration / 60)
                } else if duration < 86400 {
                    format!("{} hours", duration / 3600)
                } else {
                    format!("{} days", duration / 86400)
                }
            },
            _ => "None".to_string(),
        };
        
        println!("{:<40} {:<15} {:<20} {:<20}\n", 
            site.url.cyan(),
            status,
            last_checked,
            downtime.red());
            
        // No blank lines between sites
    }
    
    // Offer to restart service if not running
    if !daemon_running && !sites.is_empty() {
        println!("\nwould you like to restart the monitoring service? [y/N]");
        let mut input = String::new();
        if std::io::stdin().read_line(&mut input).is_ok() {
            if input.trim().to_lowercase() == "y" {
                ensure_monitoring_service_running()?;
            }
        }
    }
    
    Ok(())
}

// Helper function to ensure the service is running
fn ensure_monitoring_service_running() -> Result<()> {
    if !is_daemon_running() {
        println!("{} Monitoring service is not running. Starting it now...", "ℹ️".blue());
        start_background_service()?;
    } else {
        println!("{} Monitoring service is already running", "✓".green());
    }
    Ok(())
} 