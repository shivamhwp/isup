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

function Write-Error-Message {
    param (
        [string]$Message
    )
    Write-Host "Error: $Message" -ForegroundColor Red
    Write-Host "Please hit me up here : https://x.com/shivamhwp" -ForegroundColor Yellow
}

# Determine latest version if not specified
try {
    if (-not $Version) {
        Write-Progress-Message "Fetching latest version..."
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/shivamhwp/isup/releases/latest"
        $Version = $latestRelease.tag_name -replace 'v', ''
    }
} catch {
    Write-Error-Message "Failed to fetch latest version"
    exit 1
}

Write-Progress-Message "Installing isup v$Version..."

# Create installation directory
$installDir = "$env:LOCALAPPDATA\isup"
try {
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -ErrorAction Stop | Out-Null
    }
} catch {
    Write-Error-Message "Failed to create installation directory"
    exit 1
}

# Set binary name and download URLs
$binary = "isup-windows-x86_64.exe"
$downloadUrl = "https://github.com/shivamhwp/isup/releases/download/v$Version/$binary"
$checksumUrl = "$downloadUrl.sha256"
$outputPath = "$installDir\isup.exe"

# Create temporary directory
$tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
New-Item -ItemType Directory -Path $tempDir -ErrorAction Stop | Out-Null
$tempFile = "$tempDir\$binary"
$tempChecksum = "$tempDir\$binary.sha256"

# Download files
Write-Progress-Message "Downloading isup..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -ErrorAction Stop
    Invoke-WebRequest -Uri $checksumUrl -OutFile $tempChecksum -ErrorAction Stop
} catch {
    Write-Error-Message "Failed to download isup. Check your internet connection"
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    exit 1
}

# Verify checksum
Write-Progress-Message "Verifying download..."
try {
    $expectedHash = Get-Content $tempChecksum -Raw
    $actualHash = (Get-FileHash -Algorithm SHA256 -Path $tempFile).Hash.ToLower()
    if ($expectedHash -ne $actualHash) {
        throw "Checksum verification failed"
    }
} catch {
    Write-Error-Message "Verification failed - the download appears to be corrupted"
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    exit 1
}

# Install binary
Write-Progress-Message "Installing isup..."
try {
    Move-Item -Force $tempFile $outputPath -ErrorAction Stop
} catch {
    Write-Error-Message "Failed to install isup. Check permissions or if the file is in use"
    Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    exit 1
}

# Add to PATH if not already there
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$installDir*") {
        [Environment]::SetEnvironmentVariable(
            "Path",
            "$userPath;$installDir",
            "User"
        )
        Write-Progress-Message "Added isup to your PATH"
    }
} catch {
    Write-Progress-Message "Note: Could not add isup to your PATH automatically"
    Write-Progress-Message "Please add $installDir to your PATH manually"
}

# Cleanup
Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

Write-Progress-Message "✅ isup v$Version installed successfully!"
Write-Progress-Message "You may need to restart your terminal for PATH changes to take effect"
Write-Progress-Message "Run 'isup --help' to get started"
Write-Progress-Message "If you encounter any issues, hit me up : https://x.com/shivamhwp" 