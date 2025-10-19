#!/bin/bash

# Build and install IINA to /Applications
# This script builds IINA in Release configuration and installs it to /Applications

set -e  # Exit on error

echo "Building IINA in Release configuration..."

# Clean and build
xcodebuild -project iina.xcodeproj \
    -scheme iina \
    -configuration Release \
    -arch arm64 \
    ONLY_ACTIVE_ARCH=NO \
    clean build

# Find the built app
APP_PATH=$(echo "$HOME/Library/Developer/Xcode/DerivedData/iina-"*/Build/Products/Release/IINA.app | awk '{print $1}')

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: Could not find built IINA.app"
    echo "Searched in: $HOME/Library/Developer/Xcode/DerivedData/iina-*/Build/Products/Release/"
    exit 1
fi

echo "Found built app at: $APP_PATH"

# Remove existing installation if present
if [ -d "/Applications/IINA.app" ]; then
    echo "Removing existing IINA.app from /Applications..."
    rm -rf "/Applications/IINA.app"
fi

# Copy to /Applications
echo "Installing IINA.app to /Applications..."
cp -R "$APP_PATH" /Applications/

echo "✓ IINA successfully installed to /Applications/IINA.app"
echo ""
echo "You can now run IINA from /Applications or Spotlight"
