use anyhow::{Result, Context, anyhow};
use std::process::Command;
use std::fs::OpenOptions;
use std::io::Write;
use std::fmt;
use std::path::PathBuf;
use chrono;

// Only include mac-notification-sys on macOS
#[cfg(target_os = "macos")]
use mac_notification_sys;

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
        
        // Add platform-specific notifiers
        #[cfg(target_os = "macos")]
        {
            // Terminal Notifier is most reliable on macOS for CLI apps
            service.add_notifier(Box::new(TerminalNotifierNotifier::new()));
            // Mac OS notifier using mac-notification-sys as backup
            service.add_notifier(Box::new(MacOSNotifier::new()));
            // Shell script and AppleScript as final backups
            service.add_notifier(Box::new(ShellScriptNotifier::new()));
            service.add_notifier(Box::new(AppleScriptNotifier::new()));
        }
        
        #[cfg(target_os = "windows")]
        {
            service.add_notifier(Box::new(WindowsPowerShellNotifier::new()));
        }
        
        #[cfg(target_os = "linux")]
        {
            service.add_notifier(Box::new(LinuxNotifySendNotifier::new()));
        }
        
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

// MacOS Notifier using mac-notification-sys
#[cfg(target_os = "macos")]
#[derive(Debug)]
struct MacOSNotifier {}

#[cfg(target_os = "macos")]
impl MacOSNotifier {
    fn new() -> Self {
        MacOSNotifier {}
    }
}

#[cfg(target_os = "macos")]
impl Notifier for MacOSNotifier {
    fn notify(&self, title: &str, body: &str) -> Result<()> {
        // Configure notification for maximum visibility
        match mac_notification_sys::Notification::new()
            .title(title)
            .subtitle("isup Monitor")
            .message(body)
            .sound("Glass") // Add sound for better visibility
            .send() {
                Ok(_) => {
                    log_to_file("macOS native notification sent successfully");
                    Ok(())
                },
                Err(e) => {
                    log_to_file(&format!("Detailed macOS notification error: {:?}", e));
                    
                    // Fall back to AppleScript if the native method fails
                    log_to_file("Falling back to AppleScript for notification");
                    let script = format!(
                        "display notification \"{}\" with title \"{}\" subtitle \"isup\"",
                        body.replace("\"", "\\\""),
                        title.replace("\"", "\\\"")
                    );
                    
                    match Command::new("osascript")
                        .arg("-e")
                        .arg(&script)
                        .output() {
                            Ok(output) if output.status.success() => {
                                log_to_file("Fallback AppleScript notification succeeded");
                                Ok(())
                            },
                            _ => Err(anyhow!("macOS notification failed: {}", e))
                        }
                }
            }
    }
    
    fn name(&self) -> &'static str {
        "macOS-Native"
    }
}

// Shell Script Notifier - Uses our custom notification script
#[derive(Debug)]
struct ShellScriptNotifier {}

impl ShellScriptNotifier {
    fn new() -> Self {
        ShellScriptNotifier {}
    }
    
    fn get_script_path() -> PathBuf {
        // Try multiple approaches to find the script
        let mut paths = vec![];
        
        // 1. Try executable directory
        if let Ok(mut exe_path) = std::env::current_exe() {
            // Add the executable directory itself
            let mut exe_dir = exe_path.clone();
            exe_dir.pop();
            exe_dir.push("notify.sh");
            paths.push(exe_dir);
            
            // Add scripts subdirectory of executable directory
            exe_path.pop();
            exe_path.push("scripts");
            exe_path.push("notify.sh");
            paths.push(exe_path);
        }
        
        // 2. Try current working directory
        if let Ok(mut cwd) = std::env::current_dir() {
            // Add the current directory itself
            let mut current_dir = cwd.clone();
            current_dir.push("notify.sh");
            paths.push(current_dir);
            
            // Add scripts subdirectory
            cwd.push("scripts");
            cwd.push("notify.sh");
            paths.push(cwd);
        }
        
        // 3. Try relative paths
        paths.push(PathBuf::from("./scripts/notify.sh"));
        paths.push(PathBuf::from("./notify.sh"));
        
        // 4. Try standard installation paths
        paths.push(PathBuf::from("/usr/local/bin/isup-notify.sh"));
        paths.push(PathBuf::from("/usr/local/share/isup/notify.sh"));
        
        // 5. Try home directory
        if let Some(mut home_dir) = dirs::home_dir() {
            home_dir.push(".isup");
            home_dir.push("notify.sh");
            paths.push(home_dir);
        }
        
        // Log all attempted paths
        for path in &paths {
            log_to_file(&format!("Checking script path: {:?}, exists: {}", path, path.exists()));
        }
        
        // Return the first path that exists
        for path in &paths {
            if path.exists() {
                log_to_file(&format!("Using notification script at: {:?}", path));
                return path.clone();
            }
        }
        
        // If no path exists, create a temporary script
        log_to_file("No valid notification script path found! Creating temporary script...");
        if let Some(temp_path) = Self::create_temporary_script() {
            log_to_file(&format!("Created temporary script at: {:?}", temp_path));
            return temp_path;
        }
        
        // If all else fails, return the first path (will fail with clear error)
        log_to_file("Failed to create temporary script, using first path as fallback");
        paths[0].clone()
    }
    
    // Create a temporary notification script if none exists
    fn create_temporary_script() -> Option<PathBuf> {
        use std::io::Write;
        
        let temp_dir = std::env::temp_dir();
        let script_path = temp_dir.join("isup-notify.sh");
        
        // Basic notification script content
        let script_content = r#"#!/bin/bash
# Temporary notification script created by isup
# Log file for debugging
LOG_FILE="/tmp/isup_notify.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if we have enough arguments
if [ $# -lt 2 ]; then
    log_message "error: not enough arguments. usage: $0 \"title\" \"message\""
    exit 1
fi

TITLE="$1"
MESSAGE="$2"

log_message "attempting to send notification:"
log_message "title: $TITLE"
log_message "message: $MESSAGE"

# Detect platform
PLATFORM="unknown"
case "$(uname -s)" in
    Darwin*)    PLATFORM="darwin";;
    Linux*)     PLATFORM="linux";;
    MSYS*|MINGW*) PLATFORM="windows";;
    *)          PLATFORM="unknown";;
esac

log_message "detected platform: $PLATFORM"

if [ "$PLATFORM" = "darwin" ]; then
    # Try AppleScript
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" subtitle \"isup\""
    if [ $? -eq 0 ]; then
        log_message "notification sent successfully with applescript"
        exit 0
    fi
elif [ "$PLATFORM" = "linux" ]; then
    # Try notify-send
    if command -v notify-send &> /dev/null; then
        notify-send --urgency=critical --app-name=isup "$TITLE" "$MESSAGE"
        if [ $? -eq 0 ]; then
            log_message "notification sent successfully with notify-send"
            exit 0
        fi
    fi
fi

# Fall back to console notification
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "! $TITLE"
echo "! $MESSAGE"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""
exit 0
"#;
        
        // Try to write the script file
        match std::fs::File::create(&script_path) {
            Ok(mut file) => {
                if file.write_all(script_content.as_bytes()).is_ok() {
                    // Make the script executable
                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::PermissionsExt;
                        if let Ok(metadata) = std::fs::metadata(&script_path) {
                            let mut perms = metadata.permissions();
                            perms.set_mode(0o755); // rwxr-xr-x
                            let _ = std::fs::set_permissions(&script_path, perms);
                        }
                    }
                    return Some(script_path);
                }
            },
            Err(_) => {}
        }
        
        None
    }
}

impl Notifier for ShellScriptNotifier {
    fn notify(&self, title: &str, body: &str) -> Result<()> {
        let script_path = Self::get_script_path();
        
        log_to_file(&format!("Using script at: {:?}", script_path));
        
        if !script_path.exists() {
            return Err(anyhow!("Notification script not found at {:?}", script_path));
        }
        
        let output = Command::new(&script_path)
            .arg(title)
            .arg(body)
            .output()
            .context("Failed to execute notification script")?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let stdout = String::from_utf8_lossy(&output.stdout);
            log_to_file(&format!("Script stdout: {}", stdout));
            log_to_file(&format!("Script stderr: {}", stderr));
            return Err(anyhow!("Notification script failed: {}", stderr));
        } else {
            // Log success output
            let stdout = String::from_utf8_lossy(&output.stdout);
            log_to_file(&format!("Script success output: {}", stdout));
        }
        
        Ok(())
    }
    
    fn name(&self) -> &'static str {
        "Shell-Script"
    }
}

// Terminal Notifier for macOS - highly reliable for CLI apps
#[cfg(target_os = "macos")]
#[derive(Debug)]
struct TerminalNotifierNotifier {}

#[cfg(target_os = "macos")]
impl TerminalNotifierNotifier {
    fn new() -> Self {
        TerminalNotifierNotifier {}
    }
}

#[cfg(target_os = "macos")]
impl Notifier for TerminalNotifierNotifier {
    fn notify(&self, title: &str, body: &str) -> Result<()> {
        let script_path = ShellScriptNotifier::get_script_path();
        
        log_to_file(&format!("Using notify script at: {:?}", script_path));
        
        let output = Command::new(&script_path)
            .arg(title)
            .arg(body)
            .output()
            .with_context(|| format!("Failed to execute notification script at {:?}", script_path))?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            log_to_file(&format!("Notification script error: {}", stderr));
            return Err(anyhow!("Notification script failed: {}", stderr));
        }
        
        Ok(())
    }
    
    fn name(&self) -> &'static str {
        "Terminal-Notifier"
    }
}

// AppleScript Notifier for macOS
#[cfg(target_os = "macos")]
#[derive(Debug)]
struct AppleScriptNotifier {}

#[cfg(target_os = "macos")]
impl AppleScriptNotifier {
    fn new() -> Self {
        AppleScriptNotifier {}
    }
}

#[cfg(target_os = "macos")]
impl Notifier for AppleScriptNotifier {
    fn notify(&self, title: &str, body: &str) -> Result<()> {
        // Make the notification more prominent with longer duration
        let script = format!(
            "display notification \"{}\" with title \"{}\" subtitle \"isup\"",
            body.replace("\"", "\\\""),
            title.replace("\"", "\\\"")
        );
        
        log_to_file(&format!("Executing AppleScript: {}", script));
        
        let output = Command::new("osascript")
            .arg("-e")
            .arg(&script)
            .output()
            .context("Failed to execute AppleScript notification")?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            // Log stdout as well for debugging
            let stdout = String::from_utf8_lossy(&output.stdout);
            log_to_file(&format!("AppleScript stdout: {}", stdout));
            return Err(anyhow!("AppleScript failed: {}", stderr));
        } else {
            // Log success details
            let stdout = String::from_utf8_lossy(&output.stdout);
            log_to_file(&format!("AppleScript success, stdout: {}", stdout));
        }
        
        Ok(())
    }
    
    fn name(&self) -> &'static str {
        "AppleScript"
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

// Public API for notifications - THIS IS THE MISSING FUNCTION
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

// Log notification attempt to help with debugging - THIS IS THE MISSING FUNCTION
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

// Helper functions for Windows notifications
#[cfg(target_os = "windows")]
#[derive(Debug)]
struct WindowsPowerShellNotifier {}

#[cfg(target_os = "windows")]
impl WindowsPowerShellNotifier {
    fn new() -> Self {
        WindowsPowerShellNotifier {}
    }
}

#[cfg(target_os = "windows")]
impl Notifier for WindowsPowerShellNotifier {
    fn notify(&self, title: &str, body: &str) -> Result<()> {
        // PowerShell script to show a notification using System.Windows.Forms
        let ps_script = format!(
            "Add-Type -AssemblyName System.Windows.Forms; \
            $notify = New-Object System.Windows.Forms.NotifyIcon; \
            $notify.Icon = [System.Drawing.SystemIcons]::Information; \
            $notify.Visible = $true; \
            $notify.BalloonTipTitle = 'isup: {}'; \
            $notify.ShowBalloonTip(0, 'isup: {}', '{}', [System.Windows.Forms.ToolTipIcon]::Info);",
            title.replace("'", "''"),
            title.replace("'", "''"),
            body.replace("'", "''")
        );
        
        let output = Command::new("powershell")
            .arg("-Command")
            .arg(&ps_script)
            .output()
            .context("Failed to execute PowerShell notification")?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("PowerShell notification failed: {}", stderr));
        }
        
        Ok(())
    }
    
    fn name(&self) -> &'static str {
        "Windows-PowerShell"
    }
}

// Linux Notifier using notify-send command
#[cfg(target_os = "linux")]
#[derive(Debug)]
struct LinuxNotifySendNotifier {}

#[cfg(target_os = "linux")]
impl LinuxNotifySendNotifier {
    fn new() -> Self {
        LinuxNotifySendNotifier {}
    }
}

#[cfg(target_os = "linux")]
impl Notifier for LinuxNotifySendNotifier {
    fn notify(&self, title: &str, body: &str) -> Result<()> {
        // Get the icon path
        let icon_path = get_icon_path();
        let icon = icon_path.to_str().unwrap_or("isup.svg");
        
        let output = Command::new("notify-send")
            .arg(format!("isup: {}", title))
            .arg(body)
            .arg("--icon")
            .arg(icon)
            .arg("--urgency=critical")
            .arg("--app-name=isup")
            .output()
            .context("Failed to execute notify-send")?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow!("notify-send failed: {}", stderr));
        }
        
        Ok(())
    }
    
    fn name(&self) -> &'static str {
        "Linux-NotifySend"
    }
} 