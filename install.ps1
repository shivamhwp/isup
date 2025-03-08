# PowerShell script for installing isup on Windows

Write-Host "Installing isup CLI tool on Windows..." -ForegroundColor Blue

# Check if Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Git is not installed." -ForegroundColor Red
    Write-Host "Please install Git first by downloading from: https://git-scm.com/download/win"
    exit 1
}

# Check if Rust is installed
if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Rust is not installed." -ForegroundColor Red
    Write-Host "Please install Rust first by visiting: https://www.rust-lang.org/tools/install"
    exit 1
}

# Check if cargo is available
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Cargo is not available." -ForegroundColor Red
    Write-Host "Please ensure Rust is properly installed with Cargo."
    exit 1
}

# Create a temporary directory
$TMP_DIR = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $TMP_DIR | Out-Null
Write-Host "Working in temporary directory: $TMP_DIR"

# Clone the repository
Write-Host "Cloning the isup repository..."
git clone https://github.com/shivamhwp/isup.git (Join-Path $TMP_DIR "isup")
Set-Location (Join-Path $TMP_DIR "isup")

# Build and install
Write-Host "Building and installing isup..."
cargo install --path .

# Check if installation was successful
if (Get-Command isup -ErrorAction SilentlyContinue) {
    Write-Host "isup has been successfully installed!" -ForegroundColor Green
    Write-Host "You can now use it by running: isup example.com" -ForegroundColor Yellow
} else {
    Write-Host "Installation may have failed." -ForegroundColor Red
    Write-Host "Please ensure that your Cargo bin directory is in your PATH."
    Write-Host "You may need to restart your terminal or add %USERPROFILE%\.cargo\bin to your PATH"
}

# Clean up
Write-Host "Cleaning up..."
Set-Location $env:TEMP
Remove-Item -Recurse -Force $TMP_DIR -ErrorAction SilentlyContinue
if (Test-Path $TMP_DIR) {
    Write-Host "Could not remove temp directory. You may need to remove it manually: $TMP_DIR" -ForegroundColor Yellow
}

Write-Host "Installation complete!" -ForegroundColor Green 