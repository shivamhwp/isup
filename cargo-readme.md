# isup

on-device monitoring. lightweight, instant and efficient.

## Features

- check if a website or service is up, also can check if a particular route is up or not.
- check multiple websites/services at once
- monitor sites continuously with customizable intervals.
- receive on-device notifications when site/services status changes.
- can automatically ping your servers to keep them awake.

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
