#!/usr/bin/env bash
# Build the Flutter web app for https://mano-agency.henderlandcorps.in
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Fetching Flutter packages..."
flutter pub get

echo "Building release web app..."
flutter build web --release --base-href / --no-web-resources-cdn

# Make sure host-specific deployment files are present even if a future
# Flutter version skips hidden files when copying web/.
cp web/.htaccess build/web/.htaccess
cp web/_headers build/web/_headers
cp web/_redirects build/web/_redirects

echo
echo "Build complete: build/web"
echo "Upload the CONTENTS of build/web (including hidden files) to the"
echo "mano-agency.henderlandcorps.in document root."
