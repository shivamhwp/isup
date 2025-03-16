use anyhow::{Result, anyhow};
use std::fmt;
use std::path::PathBuf;
use std::fs::OpenOptions;
use std::io::Write;
use chrono;

// We'll define a trait for notifications to standardize the interface
trait Notifier: fmt::Debug {
    fn notify(&self, title: &str, body: &str) -> Result<()>;
    fn name(&self) -> &'static str;
}

#[allow(dead_code)]
// Path to the application icon
fn get_icon_path() -> PathBuf {
    // Try different locations for the icon
    let possible_paths = [
        "isup.png",                             // Current directory
        "./assets/isup.png",                    // Assets directory
        "/usr/share/icons/hicolor/scalable/apps/isup.png", // Linux system icon
        "/Applications/isup.app/Contents/Resources/isup.png", // macOS app bundle
    ];
    
    for path in possible_paths.iter() {
        let path_buf = PathBuf::from(path);
        if path_buf.exists() {
            return path_buf;
        }
    }
    
    // Default fallback - just return the name and let the OS find it
    PathBuf::from("isup.png")
}

// Notification service that manages multiple notifiers
pub struct NotificationService {
    notifiers: Vec<Box<dyn Notifier>>,
}

impl NotificationService {
    pub fn new() -> Self {
        let mut service = NotificationService {
            notifiers: Vec::new(),
        };
        
        // Add notifica notifier as the primary notifier
        service.add_notifier(Box::new(NotificaNotifier::new()));
        
        // Add fallback notifier for all platforms
        service.add_notifier(Box::new(ConsoleNotifier::new()));
        
        service
    }
    
    fn add_notifier(&mut self, notifier: Box<dyn Notifier>) {
        self.notifiers.push(notifier);
    }
    
    pub fn send_notification(&self, title: &str, body: &str) -> Result<()> {
        log_to_file(&format!("Attempting to send notification: '{}' - '{}'", title, body));
        
        // Try each notifier in order until one succeeds
        for notifier in &self.notifiers {
            log_to_file(&format!("Trying notifier: {}", notifier.name()));
            match notifier.notify(title, body) {
                Ok(()) => {
                    log_to_file(&format!("Notification successful with {}", notifier.name()));
                    return Ok(());
                },
                Err(e) => {
                    log_to_file(&format!("Notification with {} failed: {}", notifier.name(), e));
                    // Continue to next notifier
                }
            }
        }
        
        // If we get here, all notifiers failed
        log_to_file("All notification methods failed");
        Err(anyhow!("All notification methods failed"))
    }
}


#[derive(Debug)]
struct NotificaNotifier {}

impl NotificaNotifier {
    fn new() -> Self {
        NotificaNotifier {}
    }
}

impl Notifier for NotificaNotifier {
    fn notify(&self, title: &str, body: &str) -> Result<()> {
        log_to_file(&format!("Sending notification via notifica: {} - {}", title, body));
        
        match notifica::notify(title, body) {
            Ok(_) => {
                log_to_file("Notification sent successfully with notifica");
                Ok(())
            },
            Err(e) => {
                log_to_file(&format!("Notifica notification failed: {}", e));
                Err(anyhow!("Notifica notification failed: {}", e))
            }
        }
    }
    
    fn name(&self) -> &'static str {
        "Notifica"
    }
}

// ConsoleNotifier - Fallback for all platforms
#[derive(Debug)]
struct ConsoleNotifier {}

impl ConsoleNotifier {
    fn new() -> Self {
        ConsoleNotifier {}
    }
}

impl Notifier for ConsoleNotifier {
    fn notify(&self, title: &str, body: &str) -> Result<()> {
        println!("\n{}", "!".repeat(50));
        println!("{}", title);
        println!("{}", body);
        println!("{}\n", "!".repeat(50));
        Ok(())
    }
    
    fn name(&self) -> &'static str {
        "Console"
    }
}

// Public API for notifications
pub fn send_notification(
    url: &str, 
    is_down: bool, 
    status: &str
) -> Result<()> {
    let title = if is_down {
        format!("🚨 site down: {}", url)
    } else {
        format!(" 👍 site recovered: {}", url)
    };
    
    let body = if is_down {
        format!("{} is down! status: {}", url, status)
    } else {
        format!("{} is up! status: {}", url, status)
    };
    
    // Create a notification service
    let service = NotificationService::new();
    
    // Send notification and record result
    let result = service.send_notification(&title, &body);
    
    // Log the attempt regardless of success/failure
    log_notification_attempt(url, is_down, status, &result);
    
    // Even if notification fails, don't fail the process
    Ok(())
}

// Helper for NotifyMethod enum (kept for backward compatibility)
pub enum NotifyMethod {
    Device,
}

impl From<&str> for NotifyMethod {
    fn from(_value: &str) -> Self {
        // Currently only supporting device notifications
        NotifyMethod::Device
    }
}

// Log notification attempt to help with debugging
pub fn log_notification_attempt(url: &str, is_down: bool, status: &str, result: &Result<()>) {
    let timestamp = chrono::Local::now().format("%Y-%m-%d %H:%M:%S");
    let status_type = if is_down { "DOWN" } else { "UP" };
    
    let message = match result {
        Ok(_) => {
            format!("[{}] Notification sent: {} is {} ({})", timestamp, url, status_type, status)
        },
        Err(e) => {
            format!("[{}] Notification failed: {} is {} ({}). Error: {}", 
                timestamp, url, status_type, status, e)
        }
    };
    
    println!("{}", message);
    log_to_file(&message);
}

// Helper function to log to a dedicated notification log file
fn log_to_file(message: &str) {
    let timestamp = chrono::Local::now().format("%Y-%m-%d %H:%M:%S");
    let log_message = format!("[{}] {}\n", timestamp, message);
    
    if let Ok(mut file) = OpenOptions::new()
        .create(true)
        .append(true)
        .open("/tmp/isup_notifications.log") 
    {
        let _ = file.write_all(log_message.as_bytes());
    }
} 