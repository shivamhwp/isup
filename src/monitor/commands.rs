use anyhow:: Result;
use colored::*;
use std::time::{SystemTime, UNIX_EPOCH};
use terminal_size::terminal_size;

use crate::monitor::db::{add_site_to_db, get_all_sites, get_site_by_url, remove_site_from_db, Site};
use crate::monitor::service::{start_background_service, is_daemon_running};

pub fn  add_site(
    url: &str,
    interval: f64,
    notify: &str
) -> Result<()> {
    // Ensure the URL has a proper scheme; if missing, default to "https://".
    let formatted_url = if !url.starts_with("http://") && !url.starts_with("https://") {
        format!("https://{}", url)
    } else {
        url.to_string()
    };

    // Check if the site is already being monitored.
    if get_site_by_url(&formatted_url)?.is_some() {
        println!("{} is already being monitored", formatted_url.cyan());
        return Ok(());
    }

    // Validate the notification method; currently only "device" notifications are supported.
    if notify != "device" {
        println!("Note: Currently only device notifications are supported.");
    }

    // Construct the new site record.
    let site = Site {
        id: None,
        url: formatted_url.clone(),
        interval,
        notify_method: "device".to_string(), // Always enforce device notifications.
        is_up: None,
        last_checked: None,
        last_status: None,
        downtime_started: None,
    };

    // Add the new site to the database.
    add_site_to_db(&site)?;

    println!(
        "{} {} to monitoring with {} second interval",
        "added".green().bold(),
        formatted_url.cyan(),
        interval.to_string().yellow()
    );

    // Ensure that the background monitoring service is running.
    ensure_monitoring_service_running()?;

    Ok(())
}

pub fn list_sites() -> Result<()> {
    let sites = get_all_sites()?;
    
    // Get terminal width for responsive layout
    let term_width = terminal_size().map(|(w, _)| w.0 as usize).unwrap_or(80);
    
    if sites.is_empty() {
        println!("{}", "  no sites are currently being monitored".yellow().italic());
        return Ok(());
    }
    
    let daemon_running = is_daemon_running();
    
    // Service status header with clean styling
    println!("{}", "─".repeat(term_width.min(80)));
    if !daemon_running {
        println!(" {}  {}", "warning".yellow().bold(), 
            "monitoring service is not running. no sites are being checked.".yellow());
        println!(" {}  Run 'isup status' to check service status", "→".yellow());
    } else {
        println!(" {}  {}", "active".green().bold(), 
            "monitoring service is running normally".green());
    }
    println!("{}", "─".repeat(term_width.min(80)));

    // Dynamic column widths based on terminal size
    let url_width = (term_width * 50 / 100).min(35);

    // Header with clean separators
    println!(" {:<width$} │ {:<8} │ {:<10}", 
        "URL".bold(), 
        "STATUS".bold(), 
        "INTERVAL".bold(),
        width = url_width
    );
    println!("{}", "─".repeat(term_width.min(80)));

    for (_i, site) in sites.into_iter().enumerate() {
        let status = match site.is_up {
            Some(true) => "● UP".green().bold(),
            Some(false) => "● DOWN".red().bold(),
            None => "○ UNKNOWN".yellow().bold(),
        };
    
        println!(" {:<width$} │ {:<8} │ {:<10}", 
            site.url.cyan(),
            status,
            format!("{}s", site.interval),
            width = url_width
        );
    }
    println!("{}", "─".repeat(term_width.min(80)));
    Ok(())
}
pub fn remove_site(url: &str) -> Result<()> {
    let term_width = terminal_size().map(|(w, _)| w.0 as usize).unwrap_or(80);
    println!("{}", "─".repeat(term_width.min(80)));
    
    // Ensure URL has a scheme
    let url = if !url.starts_with("http://") && !url.starts_with("https://") {
        format!("https://{}", url)
    } else {
        url.to_string()
    };
    
    // Check if the site exists before attempting removal
    if get_site_by_url(&url)?.is_none() {
        println!("{} is not being monitored", url.cyan());
        println!("{}", "─".repeat(term_width.min(80)));
        return Ok(());
    }
    
    // Remove from database
    if remove_site_from_db(&url)? {
        println!("{} {} from monitoring", "removed".green().bold(), url.cyan());
        
        // Verify the site was actually removed
        if get_site_by_url(&url)?.is_none() {
            println!("✅ site successfully removed from database.");
        } else {
                println!("⚠️ site may still be in the database. please try again.");
        }
    } else {
        println!("⚠️ failed to remove {} from monitoring", url.cyan());
    }
    
    println!("{}", "─".repeat(term_width.min(80)));
    Ok(())
}

pub fn status_sites() -> Result<()> {
    let sites = get_all_sites()?;
    let term_width = terminal_size().map(|(w, _)| w.0 as usize).unwrap_or(80);
    
    if sites.is_empty() {
        println!("{}", "  no sites are currently being monitored".yellow().italic());
        return Ok(());
    }
    
    let daemon_running = is_daemon_running();
    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;

    // Modern header with status indicator
    println!("{}", "─".repeat(term_width.min(80)));
    if !daemon_running {
        println!(" {}  {}", "⚠ warning".yellow().bold(), 
            "monitoring service is not running".yellow());
    } else {
        println!(" {}  {}", "✓ active".green().bold(), 
            "monitoring service is running normally".green());
    }
    println!("{}", "─".repeat(term_width.min(80)));

    // Dynamic column widths
    let url_width = (term_width * 40 / 100).min(35);
    
    println!(" {:<width$} │ {:<8} │ {:<15} │ {:<10}", 
        "URL".bold(), 
        "STATUS".bold(), 
        "LAST CHECKED".bold(), 
        "DOWNTIME".bold(),
        width = url_width
    );
    println!("{}", "─".repeat(term_width.min(80)));

    for (_i, site) in sites.iter().enumerate() {
        let status = match site.is_up {
            Some(true) => "● UP".green().bold(),
            Some(false) => "● DOWN".red().bold(),
            None => "○ UNKNOWN".yellow().bold(),
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
        
        println!(" {:<width$} │ {:<8} │ {:<15} │ {:<10}", 
            site.url.cyan(),
            status,
            last_checked.italic(),
            if downtime == "None" { downtime } else { downtime.red().to_string() },
            width = url_width
        );
    }
    println!("{}", "─".repeat(term_width.min(80)));

    // Offer to restart service if not running
    if !daemon_running && !sites.is_empty() {
        println!("would you like to restart the monitoring service? [y/N]");
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
        println!("{} monitoring service is not running. starting it now...", "ℹ".blue());
        start_background_service()?;
    } else {
        println!("{} monitoring service is already running", "✓".green());
    }
    Ok(())
} 