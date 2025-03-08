# isup

A simple CLI tool written in Rust to check if a website or service is up.

## Features

- Check if a website or service is up
- Check multiple websites/services at once
- Configurable timeout
- Colorful output
- Automatically adds https:// if no scheme is provided

## Installation

### From source

```bash
# Clone the repository
git clone https://github.com/yourusername/isup.git
cd isup

# Build and install
cargo install --path .
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

## License

MIT
