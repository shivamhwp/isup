use anyhow::{Result, Context};
use rusqlite::{Connection, params};
use std::time::{SystemTime, UNIX_EPOCH};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct Site {
    pub id: Option<i64>,
    pub url: String,
    pub interval: f64,
    pub notify_method: String,
    pub is_up: Option<bool>,
    pub last_checked: Option<i64>,
    pub last_status: Option<String>,
    pub downtime_started: Option<i64>,
}

fn get_db_path() -> PathBuf {
    // Get user's home directory for data storage
    let mut data_dir = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
    data_dir.push(".isup");
    
    // Create the directory if it doesn't exist
    if !data_dir.exists() {
        let _ = fs::create_dir_all(&data_dir);
    }
    
    // Add database file name
    data_dir.push("sites.db");
    data_dir
}

fn get_db_connection() -> Result<Connection> {
    let db_path = get_db_path();
    
    // Open connection to SQLite database
    let conn = Connection::open(&db_path)
        .with_context(|| format!("Failed to open database at {:?}", db_path))?;
    
    // Create tables if they don't exist
    conn.execute(
        "CREATE TABLE IF NOT EXISTS sites (
            id INTEGER PRIMARY KEY,
            url TEXT NOT NULL UNIQUE,
            interval REAL NOT NULL,
            notify_method TEXT NOT NULL,
            is_up INTEGER,
            last_checked INTEGER,
            last_status TEXT,
            downtime_started INTEGER
        )",
        params![],
    )?;
    
    Ok(conn)
}

pub fn add_site_to_db(site: &Site) -> Result<i64> {
    let conn = get_db_connection()?;
    
    // Insert new site record
    conn.execute(
        "INSERT INTO sites (url, interval, notify_method) VALUES (?1, ?2, ?3)",
        params![site.url, site.interval, site.notify_method],
    )?;
    
    // Get the ID of the inserted record
    let id = conn.last_insert_rowid();
    
    Ok(id)
}

pub fn get_site_by_url(url: &str) -> Result<Option<Site>> {
    let conn = get_db_connection()?;
    
    // Query for site with the given URL
    let mut stmt = conn.prepare(
        "SELECT id, url, interval, notify_method, is_up, last_checked, last_status, downtime_started 
         FROM sites 
         WHERE url = ?1"
    )?;
    
    let mut rows = stmt.query(params![url])?;
    
    // Process first row (if any)
    if let Some(row) = rows.next()? {
        Ok(Some(Site {
            id: Some(row.get(0)?),
            url: row.get(1)?,
            interval: row.get(2)?,
            notify_method: row.get(3)?,
            is_up: row.get(4)?,
            last_checked: row.get(5)?,
            last_status: row.get(6)?,
            downtime_started: row.get(7)?,
        }))
    } else {
        Ok(None)
    }
}

pub fn get_all_sites() -> Result<Vec<Site>> {
    let conn = get_db_connection()?;
    
    // Query for all sites
    let mut stmt = conn.prepare(
        "SELECT id, url, interval, notify_method, is_up, last_checked, last_status, downtime_started 
         FROM sites 
         ORDER BY url"
    )?;
    
    let site_iter = stmt.query_map(params![], |row| {
        Ok(Site {
            id: Some(row.get(0)?),
            url: row.get(1)?,
            interval: row.get(2)?,
            notify_method: row.get(3)?,
            is_up: row.get(4)?,
            last_checked: row.get(5)?,
            last_status: row.get(6)?,
            downtime_started: row.get(7)?,
        })
    })?;
    
    // Convert to Vec and filter out any errors
    let sites: Result<Vec<Site>, _> = site_iter.collect();
    Ok(sites?)
}

pub fn remove_site_from_db(url: &str) -> Result<bool> {
    let conn = get_db_connection()?;
    
    // Delete site with the given URL
    let rows_affected = conn.execute(
        "DELETE FROM sites WHERE url = ?1",
        params![url],
    )?;
    
    // Return success if at least one row was deleted
    Ok(rows_affected > 0)
}

pub fn update_site_status(url: &str, is_up: bool, status: &str) -> Result<()> {
    let conn = get_db_connection()?;
    let now = SystemTime::now().duration_since(UNIX_EPOCH)?.as_secs() as i64;
    
    // Get existing site status for downtime tracking
    let existing_site = get_site_by_url(url)?;
    let downtime_started = match (existing_site, is_up) {
        // Site was previously up but is now down - start downtime tracking
        (Some(site), false) if site.is_up == Some(true) => Some(now),
        
        // Site was previously down and is still down - keep existing downtime
        (Some(site), false) => site.downtime_started,
        
        // Site is up, so no downtime
        (_, true) => None,
        
        // Default case - shouldn't happen but for safety
        _ => None,
    };
    
    // Update the site status
    conn.execute(
        "UPDATE sites 
         SET is_up = ?1, 
             last_checked = ?2, 
             last_status = ?3,
             downtime_started = ?4
         WHERE url = ?5",
        params![is_up, now, status, downtime_started, url],
    )?;
    
    Ok(())
} 