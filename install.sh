#!/bin/bash
set -e

# Determine latest version if not specified
VERSION=${1:-$(curl -s https://api.github.com/repos/shivamhwp/isup/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')}

# Determine OS
OS="unknown"
case "$(uname -s)" in
    Linux*)     OS="linux";;
    Darwin*)    OS="macos";;
    *)          echo "Unsupported OS. Please download manually from https://github.com/shivamhwp/isup/releases"; exit 1;;
esac

# Create installation directory
INSTALL_DIR="/usr/local/bin"
if [ ! -d "$INSTALL_DIR" ] || [ ! -w "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
fi

echo "Downloading isup v${VERSION} for ${OS}..."

# Download the binary
DOWNLOAD_URL="https://github.com/shivamhwp/isup/releases/download/v${VERSION}/isup-${OS}-${VERSION}"
curl -L "$DOWNLOAD_URL" -o "${INSTALL_DIR}/isup"
chmod +x "${INSTALL_DIR}/isup"

# Handle macOS security measures
if [ "$OS" = "macos" ]; then
    echo "Setting up for macOS security..."
    
    # Try to remove quarantine with user permission if needed
    if command -v xattr >/dev/null 2>&1; then
        if ! xattr -d com.apple.quarantine "${INSTALL_DIR}/isup" 2>/dev/null; then
            echo "Attempting to remove quarantine attribute with sudo..."
            sudo xattr -d com.apple.quarantine "${INSTALL_DIR}/isup" 2>/dev/null || true
        fi
    fi
    
    # Try to run it with sudo to pre-approve
    echo "Attempting to pre-approve isup..."
    if sudo "${INSTALL_DIR}/isup" --version >/dev/null 2>&1; then
        echo "✅ isup has been approved for use!"
    else
        echo "⚠️  You may need to manually approve isup on first run."
        echo "   Go to System Preferences → Security & Privacy after first run."
    fi
    
    # Create a temporary launcher script that handles approval
    LAUNCHER="${INSTALL_DIR}/isup-launcher.sh"
    cat > "$LAUNCHER" << 'EOF'
    
#!/bin/bash
BINARY_PATH="$(dirname "$0")/isup"
if ! "$BINARY_PATH" "$@"; then
    echo "First run may require approval. Attempting to approve..."
    xattr -d com.apple.quarantine "$BINARY_PATH" 2>/dev/null || sudo xattr -d com.apple.quarantine "$BINARY_PATH" 2>/dev/null || true
    echo "Please try running isup again, or approve it in System Preferences → Security & Privacy"
fi
EOF
    chmod +x "$LAUNCHER"
    
    echo "Created a launcher script that will help with first-run approval."
    echo "For the first run, you can use: ${LAUNCHER}"
fi

echo "isup has been installed to ${INSTALL_DIR}/isup"

# Check if directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "NOTE: Make sure ${INSTALL_DIR} is in your PATH."
    
    # Suggest adding to PATH based on shell
    SHELL_NAME="$(basename "$SHELL")"
    if [ "$SHELL_NAME" = "bash" ]; then
        echo "You can add it by running:"
        echo "echo 'export PATH=\"\$PATH:${INSTALL_DIR}\"' >> ~/.bashrc && source ~/.bashrc"
    elif [ "$SHELL_NAME" = "zsh" ]; then
        echo "You can add it by running:"
        echo "echo 'export PATH=\"\$PATH:${INSTALL_DIR}\"' >> ~/.zshrc && source ~/.zshrc"
    fi
fi

echo "Installation complete! Run 'isup --help' to get started." 
