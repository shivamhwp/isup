# isup

![Crates.io Total Downloads](https://img.shields.io/crates/d/isup?labelColor=%23222&color=white)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/shivamhwp/isup/release.yml?labelColor=%23222&color=white)

checks whether a particular site/service/route is up or not. get on-device notificaitons, when down.

crates.io: [https://crates.io/crates/isup](https://crates.io/crates/isup)

## Features

- check if a website or service is up, also can check if a particular route is up or not.
- check multiple websites/services at once,
- monitor sites continuously with customizable intervals.
- receive on-device notifications when site status changes.
- can automatically ping your servers to keep them awake.
- auto-start on login across all platforms (macOS, Linux, Windows)

## Installation (linux, macos, wsl)

```bash
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/install.sh | bash
```

During installation, you'll be asked if you want to install isup to start automatically on login. This will configure your system to run isup in the background whenever you log in.

## Uninstallation

To completely remove isup from your system:

```bash
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/uninstall.sh | bash
```

This will remove the binary, auto-start configuration, and all data files.

## Usage

### Basic Commands

```bash
# Basic usage - can also add https:// prefix.
isup shivam.ing

# Check multiple sites at once
isup shivam.ing t3.gg twitch.tv http://localhost:6969

```

### Monitoring Commands

```bash
# Add a site to continuous monitoring
isup add shivam.ing --interval 10

# List all sites being monitored
isup list

# Check status of all monitored sites
isup status

# Remove a site from monitoring
isup remove shivam.ing

# Stop the monitoring service
isup stop-ms
```

## Auto-Start Configuration

isup can be configured to start automatically when you log in, ensuring your monitoring continues even after system restarts.

### Installing Auto-Start

If you didn't enable auto-start during installation, you can set it up later:

```bash
# Download and run the auto-start installation script
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/scripts/install-autostart.sh | bash
```

### Disabling Auto-Start

To remove the auto-start configuration without uninstalling isup:

```bash
# Download and run the auto-start uninstallation script
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/scripts/uninstall-autostart.sh | bash
```

## Command Reference

| Command                 | Description                                | Options                                                                                                              |
| ----------------------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| `isup <url> [<url>...]` | Check if one or more sites are up          | `--timeout, -t`: Set request timeout in seconds (default: 10)                                                        |
| `isup add <url>`        | Add a site to continuous monitoring        | `--interval, -i`: Check interval in seconds (default: 16.9)<br>`--notify, -n`: Notification method (default: device) |
| `isup list`             | List all sites being monitored             | None                                                                                                                 |
| `isup status`           | Show current status of all monitored sites | None                                                                                                                 |
| `isup remove <url>`     | Remove a site from monitoring              | None                                                                                                                 |
| `isup stop-ms`          | Stop the background monitoring service     | None                                                                                                                 |

## Status Indicators

When checking a site, `isup` will display one of the following status indicators:

- ✅ **UP** - The site is up and running (2xx status code)
- ⚠️ **REACHABLE** - The site is reachable but returned a non-success status code
- ⚠️ **UP but restricts automated access** - The site returned a 403 Forbidden status
- ❓ **DOES NOT EXIST** - The domain doesn't exist or returned a 404 Not Found
- ❌ **DOWN** - The site is down (5xx status code or connection error)
