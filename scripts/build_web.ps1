# Build the Flutter web app for https://mano-agency.henderlandcorps.in
#
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "Project: $projectRoot"
Write-Host "Fetching Flutter packages..."
flutter pub get

Write-Host "Building release web app..."
flutter build web --release --base-href / --no-web-resources-cdn

# Make sure host-specific deployment files are present even if a future
# Flutter version skips hidden files when copying web/.
Copy-Item "web\.htaccess" "build\web\.htaccess" -Force
Copy-Item "web\_headers" "build\web\_headers" -Force
Copy-Item "web\_redirects" "build\web\_redirects" -Force

Write-Host ""
Write-Host "Build complete: $projectRoot\build\web"
Write-Host "Upload the CONTENTS of build\web (including hidden files) to the"
Write-Host "mano-agency.henderlandcorps.in document root."
