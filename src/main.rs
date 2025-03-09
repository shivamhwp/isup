use anyhow::{Context, Result};
use clap::Parser;
use colored::*;
use reqwest::blocking::Client;
use reqwest::StatusCode;
use std::time::Duration;

mod utils;
use utils::get_status_description;

#[derive(Parser, Debug)]
#[clap(author, version, about)]
struct Args {
    /// URLs to check (e.g., https://shivam.ing)
    #[clap(required = true)]
    urls: Vec<String>,

    /// Timeout in seconds
    #[clap(short, long, default_value = "10")]
    timeout: u64,
}

fn main() -> Result<()> {
    let args = Args::parse();
    let client = Client::builder()
        .user_agent("isup/0.1.0")
        .timeout(Duration::from_secs(args.timeout))
        .build()
        .context("failed to create HTTP client")?;

        
    for url_input in &args.urls {
        // Ensure URL has a scheme
        let url = if !url_input.starts_with("http://") && !url_input.starts_with("https://") {
            format!("https://{}", url_input)
        } else {
            url_input.clone()
        };
        
        println!("checking if {} is up...", url.cyan());
        
        match check_site(&client, &url) {
            Ok(status) => {
                if status.is_success() {
                    println!("✅ {} is {}!", url.cyan(), "UP".green().bold());
                    println!("status code: {}", status.as_u16().to_string().green());
                } else {
                    let status_code = status.as_u16();
                    let description = get_status_description(status_code);
                    
                    // Categorize the response based on status code
                    
                    if status_code == 404 {
                        println!("❓ {} {}!", url.cyan(), "DOES NOT EXIST".red().bold());
                        println!("Status code: {}", status_code.to_string().red());
                        println!("Description: {}", description.red());
                    }
                    else if status_code == 403 {
                        println!("⚠️ {} is {}! but restricts automated access", url.cyan(), "up".yellow().bold());
                        println!("Status code: {}", status_code.to_string().red());
                        println!("Description: {}", description.red());
                    }
                    else if status_code >= 500 { 
                        println!("❌ {} is {}!", url.cyan(), "DOWN".red().bold());
                        println!("Status code: {}", status_code.to_string().red());
                        println!("Description: {}", description.red());
                    } else {
                        println!("⚠️ {} is {} but returned status code: {}", 
                            url.cyan(), 
                            "REACHABLE".yellow().bold(),
                            status_code.to_string().yellow());
                        println!("Description: {}", description.yellow());
                    }
                }
            },
            Err(e) => {
                // Analyze the error to determine if it's a connection issue or DNS resolution problem
                let error_string = e.to_string();
                if error_string.contains("dns error") || error_string.contains("failed to lookup address") {
                    println!("❓ {} {}!", url.cyan(), "DOES NOT EXIST".red().bold());
                    println!("{}", "Error: Domain could not be resolved - The domain name doesn't exist or DNS resolution failed".red());
                } else if error_string.contains("connection refused") {
                    println!("❌ {} is {}!", url.cyan(), "DOWN".red().bold());
                    println!("{}", "Error: Connection refused - The server actively rejected the connection".red());
                } else if error_string.contains("timeout") {
                    println!("❌ {} is {}!", url.cyan(), "DOWN".red().bold());
                    println!("{}", "Error: Connection timed out - The server did not respond within the timeout period".red());
                } else {
                    println!("❌ {} is {}!", url.cyan(), "DOWN".red().bold());
                    println!("{}", error_string.red());
                }
            }
        }
        
        // Add a newline between URL checks for better readability
        if args.urls.len() > 1 && url_input != args.urls.last().unwrap() {
            println!();
        }
    }
    
    Ok(())
}

fn check_site(client: &Client, url: &str) -> Result<StatusCode> {
    let response = client.get(url).send()?;
    Ok(response.status())
}
