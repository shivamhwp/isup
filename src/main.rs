use anyhow::{Context, Result};
use clap::Parser;
use colored::*;
use reqwest::blocking::Client;
use reqwest::StatusCode;
use std::time::Duration;

/// A CLI tool to check if a website or service is up
#[derive(Parser, Debug)]
#[clap(author, version, about)]
struct Args {
    /// URLs to check (e.g., https://example.com)
    #[clap(required = true)]
    urls: Vec<String>,

    /// Timeout in seconds
    #[clap(short, long, default_value = "10")]
    timeout: u64,
}

fn main() -> Result<()> {
    let args = Args::parse();
    
    let client = Client::builder()
        .timeout(Duration::from_secs(args.timeout))
        .build()
        .context("Failed to create HTTP client")?;
    
    for url_input in &args.urls {
        // Ensure URL has a scheme
        let url = if !url_input.starts_with("http://") && !url_input.starts_with("https://") {
            format!("https://{}", url_input)
        } else {
            url_input.clone()
        };
        
        println!("Checking if {} is up...", url.cyan());
        
        match check_site(&client, &url) {
            Ok(status) => {
                if status.is_success() {
                    println!("✅ {} is {}!", url.cyan(), "UP".green().bold());
                    println!("Status code: {}", status.as_u16().to_string().green());
                } else {
                    println!("⚠️ {} is {} but returned status code: {}", 
                        url.cyan(), 
                        "REACHABLE".yellow().bold(),
                        status.as_u16().to_string().yellow());
                }
            },
            Err(e) => {
                println!("❌ {} is {}!", url.cyan(), "DOWN".red().bold());
                println!("Error: {}", e.to_string().red());
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
