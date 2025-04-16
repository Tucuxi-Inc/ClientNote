#!/bin/bash

# This script signs the Sparkle framework components with the appropriate entitlements
# It should be run as a build phase in Xcode

# Set paths
SPARKLE_FRAMEWORK_PATH="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/Sparkle.framework"
ENTITLEMENTS_DIR="${SRCROOT}/ClientNote/Resources"

# Check if the Sparkle framework exists
if [ ! -d "$SPARKLE_FRAMEWORK_PATH" ]; then
    echo "Error: Sparkle framework not found at $SPARKLE_FRAMEWORK_PATH"
    exit 1
fi

# Check if the entitlements files exist
if [ ! -f "$ENTITLEMENTS_DIR/SparkleAutoupdate.entitlements" ] || \
   [ ! -f "$ENTITLEMENTS_DIR/SparkleUpdater.entitlements" ] || \
   [ ! -f "$ENTITLEMENTS_DIR/SparkleDownloader.entitlements" ] || \
   [ ! -f "$ENTITLEMENTS_DIR/SparkleInstaller.entitlements" ]; then
    echo "Error: One or more entitlements files not found in $ENTITLEMENTS_DIR"
    exit 1
fi

# Get the code signing identity
if [ -z "$EXPANDED_CODE_SIGN_IDENTITY" ]; then
    echo "Error: No code signing identity found. Make sure you have selected a team in Xcode."
    exit 1
fi

echo "Signing Sparkle framework components with identity: $EXPANDED_CODE_SIGN_IDENTITY"

# Sign Autoupdate
if [ -f "$SPARKLE_FRAMEWORK_PATH/Versions/B/Autoupdate" ]; then
    echo "Signing Autoupdate..."
    codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_DIR/SparkleAutoupdate.entitlements" "$SPARKLE_FRAMEWORK_PATH/Versions/B/Autoupdate"
else
    echo "Warning: Autoupdate not found at expected path"
fi

# Sign Updater
if [ -f "$SPARKLE_FRAMEWORK_PATH/Versions/B/Updater.app/Contents/MacOS/Updater" ]; then
    echo "Signing Updater..."
    codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_DIR/SparkleUpdater.entitlements" "$SPARKLE_FRAMEWORK_PATH/Versions/B/Updater.app/Contents/MacOS/Updater"
else
    echo "Warning: Updater not found at expected path"
fi

# Sign Downloader XPC
if [ -f "$SPARKLE_FRAMEWORK_PATH/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" ]; then
    echo "Signing Downloader XPC..."
    codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_DIR/SparkleDownloader.entitlements" "$SPARKLE_FRAMEWORK_PATH/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
else
    echo "Warning: Downloader XPC not found at expected path"
fi

# Sign Installer XPC
if [ -f "$SPARKLE_FRAMEWORK_PATH/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer" ]; then
    echo "Signing Installer XPC..."
    codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_DIR/SparkleInstaller.entitlements" "$SPARKLE_FRAMEWORK_PATH/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"
else
    echo "Warning: Installer XPC not found at expected path"
fi

echo "Sparkle framework components signing complete" 