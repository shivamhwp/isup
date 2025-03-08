#!/bin/bash
set -e

# Colors for output (will be disabled on Windows)
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
    # Disable colors on Windows
    RED=''
    GREEN=''
    BLUE=''
    YELLOW=''
    NC=''
fi

echo -e "${BLUE}Installing isup CLI tool on $OS...${NC}"

# Check if Git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git is not installed.${NC}"
    echo -e "Please install Git first."
    if [[ "$OS" == "windows" ]]; then
        echo -e "Download from: https://git-scm.com/download/win"
    elif [[ "$OS" == "macos" ]]; then
        echo -e "Run: brew install git"
    elif [[ "$OS" == "linux" ]]; then
        echo -e "Run: sudo apt-get install git or equivalent for your distribution"
    fi
    exit 1
fi

# Check if Rust is installed
if ! command -v rustc &> /dev/null; then
    echo -e "${RED}Error: Rust is not installed.${NC}"
    echo -e "Please install Rust first by running:"
    if [[ "$OS" == "windows" ]]; then
        echo -e "Visit https://www.rust-lang.org/tools/install and download the installer"
    else
        echo -e "${YELLOW}curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh${NC}"
    fi
    exit 1
fi

# Check if cargo is available
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: Cargo is not available.${NC}"
    echo -e "Please ensure Rust is properly installed with Cargo."
    exit 1
fi

# Create a temporary directory based on OS
if [[ "$OS" == "windows" ]]; then
    TMP_DIR=$(mktemp -d -p "$TEMP")
else
    TMP_DIR=$(mktemp -d)
fi
echo -e "Working in temporary directory: ${TMP_DIR}"

# Clone the repository
echo -e "Cloning the isup repository..."
git clone https://github.com/shivamhwp/isup.git "${TMP_DIR}/isup"
cd "${TMP_DIR}/isup"

# Build and install
echo -e "Building and installing isup..."
cargo install --path .

# Check if installation was successful
if command -v isup &> /dev/null; then
    echo -e "${GREEN}isup has been successfully installed!${NC}"
    echo -e "You can now use it by running: ${YELLOW}isup example.com${NC}"
else
    echo -e "${RED}Installation may have failed.${NC}"
    echo -e "Please ensure that your Cargo bin directory is in your PATH."
    if [[ "$OS" == "windows" ]]; then
        echo -e "You may need to restart your terminal or add %USERPROFILE%\.cargo\bin to your PATH"
    else
        echo -e "You may need to add ~/.cargo/bin to your PATH or restart your terminal"
    fi
fi

# Clean up
echo -e "Cleaning up..."
if [[ "$OS" == "windows" ]]; then
    rm -rf "${TMP_DIR}" || echo "Could not remove temp directory. You may need to remove it manually: ${TMP_DIR}"
else
    rm -rf "${TMP_DIR}"
fi

echo -e "${GREEN}Installation complete!${NC}" 
