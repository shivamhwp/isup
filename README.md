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
- auto-start on login with launch agent (macOS)

## Installation (linux, macos, wsl)

```bash
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/install.sh | bash
```

During installation on macOS, you'll be asked if you want to install isup as a launch agent. This will make isup start automatically when you log in and continue running in the background. it's super lightweight (no need to worry about memory).

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

## Launch Agent (macOS)

The launch agent ensures that isup's monitoring service runs automatically when you log in and continues running in the background, even if you close your terminal or restart your computer.

### Installing the Launch Agent

If you didn't install the launch agent during the initial installation, you can install it separately:

```bash
# Download and run the launch agent installation script
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/scripts/install-launch-agent.sh | bash
```

### Uninstalling the Launch Agent

To remove the launch agent:

```bash
# Download and run the launch agent uninstallation script
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/scripts/uninstall-launch-agent.sh | bash
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

## Uninstallation

To completely remove isup from your system:

```bash
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/uninstall.sh | bash
```

This will remove the binary, launch agent (if installed), and all data files.
