# PowerShell script for installing isup on Windows

param (
    [string]$Version = $null
)

function Write-Progress-Message {
    param (
        [string]$Message
    )
    Write-Host "=> $Message"
}

# Determine latest version if not specified
if (-not $Version) {
    Write-Progress-Message "Fetching latest version..."
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/shivamhwp/isup/releases/latest"
    $Version = $latestRelease.tag_name -replace 'v', ''
}

Write-Progress-Message "Installing isup v$Version for Windows..."

# Create installation directory
$installDir = "$env:LOCALAPPDATA\isup"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# Set binary name and download URLs
$binary = "isup-windows-x86_64.exe"
$downloadUrl = "https://github.com/shivamhwp/isup/releases/download/v$Version/$binary"
$checksumUrl = "$downloadUrl.sha256"
$outputPath = "$installDir\isup.exe"

# Create temporary directory
$tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
New-Item -ItemType Directory -Path $tempDir | Out-Null
$tempFile = "$tempDir\$binary"
$tempChecksum = "$tempDir\$binary.sha256"

# Download files
Write-Progress-Message "Downloading binary and checksum..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
Invoke-WebRequest -Uri $checksumUrl -OutFile $tempChecksum

# Verify checksum
Write-Progress-Message "Verifying checksum..."
$expectedHash = Get-Content $tempChecksum -Raw
$actualHash = (Get-FileHash -Algorithm SHA256 -Path $tempFile).Hash.ToLower()
if ($expectedHash -notmatch $actualHash) {
    Write-Host "Error: Checksum verification failed"
    Remove-Item -Recurse -Force $tempDir
    exit 1
}

# Install binary
Write-Progress-Message "Installing to $installDir..."
Move-Item -Force $tempFile $outputPath

# Add to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$userPath;$installDir",
        "User"
    )
    Write-Progress-Message "Added $installDir to your PATH."
} else {
    Write-Progress-Message "$installDir is already in your PATH."
}

# Cleanup
Remove-Item -Recurse -Force $tempDir

Write-Progress-Message "Installation complete! You may need to restart your terminal for PATH changes to take effect."
Write-Progress-Message "Try running: isup --help" 