#!/bin/bash

# Build and Deploy Script for SymptomScribe to iPhone
# Usage: ./build-and-deploy.sh [device-name]

set -e

PROJECT_PATH="SymptomScribe.xcodeproj"
SCHEME="HealthScribe"
CONFIGURATION="Debug"

echo "🔍 Finding connected iOS devices..."
DEVICES=$(xcrun xctrace list devices 2>/dev/null | grep -i "iphone\|ipad" | grep -v "Simulator" || echo "")

if [ -z "$DEVICES" ]; then
    echo "❌ No iOS devices found. Please:"
    echo "   1. Connect your iPhone via USB"
    echo "   2. Unlock your iPhone"
    echo "   3. Trust this computer if prompted"
    echo "   4. Run this script again"
    exit 1
fi

echo "📱 Available devices:"
echo "$DEVICES"
echo ""

# Get device UDID (first connected device)
DEVICE_UDID=$(xcrun xctrace list devices 2>/dev/null | grep -i "iphone\|ipad" | grep -v "Simulator" | head -1 | sed 's/.*\[\(.*\)\].*/\1/')

if [ -z "$DEVICE_UDID" ]; then
    echo "❌ Could not detect device UDID"
    exit 1
fi

DEVICE_NAME=$(xcrun xctrace list devices 2>/dev/null | grep "$DEVICE_UDID" | sed 's/\(.*\) \[.*/\1/' | xargs)
echo "✅ Using device: $DEVICE_NAME ($DEVICE_UDID)"
echo ""

echo "🔨 Building for device..."
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "id=$DEVICE_UDID" \
    -derivedDataPath ./build \
    clean build

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo ""
echo "📦 Installing app on device..."
xcrun devicectl device install app \
    --device "$DEVICE_UDID" \
    ./build/Build/Products/Debug-iphoneos/HealthScribe.app

if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️  Installation failed. This might be because:"
    echo "   1. Your device is not trusted (check Settings > General > VPN & Device Management)"
    echo "   2. Code signing is not set up properly"
    echo "   3. You need to open Xcode first and set up your development team"
    echo ""
    echo "💡 Try this:"
    echo "   1. Open SymptomScribe.xcodeproj in Xcode"
    echo "   2. Select your device from the device menu"
    echo "   3. Select your development team in Signing & Capabilities"
    echo "   4. Build and run from Xcode once (this will set up trust)"
    echo "   5. Then you can use this script"
    exit 1
fi

echo ""
echo "✅ App installed successfully!"
echo "📱 Check your iPhone for the SymptomScribe app"
