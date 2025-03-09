# PowerShell script for installing isup on Windows

# Determine latest version if not specified
param (
    [string]$Version = $null
)

if (-not $Version) {
    $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/shivamhwp/isup/releases/latest"
    $Version = $latestRelease.tag_name -replace 'v', ''
}

Write-Host "Downloading isup v$Version for Windows..."

# Create installation directory
$installDir = "$env:LOCALAPPDATA\isup"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# Download the binary
$downloadUrl = "https://github.com/shivamhwp/isup/releases/download/v$Version/isup-windows.exe-$Version"
$outputPath = "$installDir\isup.exe"

Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath

# Add to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable(
        "Path",
        "$userPath;$installDir",
        "User"
    )
    Write-Host "Added $installDir to your PATH."
    Write-Host "You may need to restart your terminal for this change to take effect."
} else {
    Write-Host "$installDir is already in your PATH."
}

Write-Host "Installation complete! Run 'isup --help' to get started." 