#!/bin/bash
set -e

progress() {
    echo "=> $1"
}

# Determine latest version if not specified
VERSION=${1:-$(curl -s https://api.github.com/repos/shivamhwp/isup/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')}

# Determine OS
PLATFORM="unknown"
case "$(uname -s)" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="darwin";;
    MSYS*|MINGW*) PLATFORM="windows";;
    *)          
        echo "Error: Unsupported platform: $(uname -s)"
        echo "Please hit me up here : https://x.com/shivamhwp"
        exit 1
        ;;
esac

ARCH="x86_64"

# Construct binary name and URLs
if [ "$PLATFORM" = "windows" ]; then
    BINARY="isup-windows-x86_64.exe"
else
    BINARY="isup-${PLATFORM}-${ARCH}"
fi

DOWNLOAD_URL="https://github.com/shivamhwp/isup/releases/download/v${VERSION}/${BINARY}"
CHECKSUM_URL="${DOWNLOAD_URL}.sha256"

# Create temporary directory
TMP_DIR=$(mktemp -d)
TMP_FILE="${TMP_DIR}/${BINARY}"
TMP_CHECKSUM="${TMP_DIR}/${BINARY}.sha256"

# Download files
progress "downloading isup v${VERSION}..."
if ! curl -sL "$DOWNLOAD_URL" -o "$TMP_FILE" || ! curl -sL "$CHECKSUM_URL" -o "$TMP_CHECKSUM"; then
    echo "Error: Failed to download isup"
    echo "Please check your internet connection or hit me up here : https://x.com/shivamhwp"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Verify checksum (silently)
progress "verifying download..."
EXPECTED_HASH=$(cat "$TMP_CHECKSUM")
if command -v sha256sum >/dev/null; then
    ACTUAL_HASH=$(sha256sum "$TMP_FILE" | awk '{print $1}')
elif command -v shasum >/dev/null; then
    ACTUAL_HASH=$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')
else
    echo "Error: No sha256sum or shasum command found"
    echo "Please install sha256sum or hit me up here : https://x.com/shivamhwp"
    rm -rf "$TMP_DIR"
    exit 1
fi

if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Verification failed - the download appears to be corrupted"
    echo "Please try again or hit me up here : https://x.com/shivamhwp"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Determine install location
if [ "$PLATFORM" = "darwin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
elif [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
fi

# Install binary
progress "installing isup..."
if ! mv "$TMP_FILE" "$INSTALL_DIR/isup" || ! chmod 755 "$INSTALL_DIR/isup"; then
    echo "Error: Failed to install isup"
    echo "Please check permissions or hit me up here : https://x.com/shivamhwp"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Handle macOS specific security (silently)
if [ "$PLATFORM" = "darwin" ]; then
    xattr -d com.apple.quarantine "$INSTALL_DIR/isup" 2>/dev/null || true
fi

# Add to PATH if needed
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    SHELL_NAME="$(basename "$SHELL")"
    if [ "$SHELL_NAME" = "zsh" ] && [ -f "$HOME/.zshrc" ]; then
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.zshrc"
        progress "added $INSTALL_DIR to your PATH in .zshrc"
    elif [ "$SHELL_NAME" = "bash" ] && [ -f "$HOME/.bashrc" ]; then
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
        progress "added $INSTALL_DIR to your PATH in .bashrc"
    else
        progress "note: add $INSTALL_DIR to your PATH to use isup from anywhere"
    fi
fi

# Cleanup
rm -rf "$TMP_DIR"

progress "✅ isup v${VERSION} installed successfully!"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    progress "restart your terminal or run 'source ~/.bashrc' or 'source ~/.zshrc'"
fi

progress "run 'isup --help' to get started"
progress "if you encounter any issues, hit me up : https://x.com/shivamhwp" 
