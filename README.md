# isup - [ work in progress ] [ not production ready]

a simple CLI tool written in Rust to check if a website or service is up.

## Features

- Check if a website or service is up
- Check multiple websites/services at once
- Configurable timeout
- Cross-platform support (Windows, macOS, Linux)

## Installation

### Quick Install

#### Unix-like systems (macOS, Linux)

```bash
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/install.sh | bash
```

#### Windows (PowerShell)

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/shivamhwp/isup/main/install.ps1 -OutFile install.ps1; .\install.ps1; Remove-Item install.ps1
```

#### Windows (Git Bash or WSL)

```bash
curl -sSL https://raw.githubusercontent.com/shivamhwp/isup/main/install.sh | bash
```

### From source

```bash
# Clone the repository
git clone https://github.com/shivamhwp/isup.git
cd isup

# Build and install
cargo install --path .
```

### From releases

You can also download pre-built binaries from the [releases page](https://github.com/shivamhwp/isup/releases).

## Usage

```bash
# Basic usage
isup example.com

# With explicit https
isup https://example.com

# Check multiple sites
isup example.com google.com github.com

# With custom timeout (in seconds)
isup example.com --timeout 5
isup example.com -t 5

```

## Examples

```bash
# Check if Google is up
isup google.com

# Check if multiple services are up
isup google.com github.com api.example.com

# Check if a specific API endpoint is up
isup api.example.com/health

# Check with a longer timeout for slow services
isup slow-service.example.com --timeout 30
```

## CI/CD

This project uses GitHub Actions for continuous integration and deployment:

- Automatically builds binaries for Windows, macOS, and Linux on new releases
- Creates release archives with installation scripts
- Updates documentation on new releases
