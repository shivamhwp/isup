# isup

![Crates.io Total Downloads](https://img.shields.io/crates/d/isup?labelColor=%23222&color=white)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/shivamhwp/isup/release.yml?labelColor=%23222&color=white)

checks whether a particular site/service/route is up or not.

crates.io: [https://crates.io/crates/isup](https://crates.io/crates/isup)

## Features

- check if a website or service is up, also can check if a particular route is up or not.
- check multiple websites/services at once,
- configurable timeout

## installation

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
