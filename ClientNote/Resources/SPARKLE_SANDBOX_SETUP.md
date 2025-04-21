# Sparkle Framework Sandbox Setup

This document provides instructions on how to properly set up the Sparkle framework with app sandbox for macOS applications.

## Overview

The Sparkle framework is used for auto-updates in macOS applications. When your app is sandboxed, the Sparkle framework components need to be properly signed with the appropriate entitlements.

## Files Included

1. `ClientNote.entitlements` - Main app entitlements with additional permissions for Sparkle
2. `SparkleAutoupdate.entitlements` - Entitlements for the Autoupdate component
3. `SparkleUpdater.entitlements` - Entitlements for the Updater component
4. `SparkleDownloader.entitlements` - Entitlements for the Downloader XPC service
5. `SparkleInstaller.entitlements` - Entitlements for the Installer XPC service
6. `sign_sparkle.sh` - Script to sign the Sparkle framework components

## Setup Instructions

### 1. Add the Entitlements Files to Your Project

1. Open your Xcode project
2. Select the ClientNote target
3. Go to the "Build Phases" tab
4. Expand the "Copy Bundle Resources" section
5. Add the following entitlements files:
   - SparkleAutoupdate.entitlements
   - SparkleUpdater.entitlements
   - SparkleDownloader.entitlements
   - SparkleInstaller.entitlements

### 2. Add the Signing Script as a Build Phase

1. In Xcode, select the ClientNote target
2. Go to the "Build Phases" tab
3. Click the "+" button and select "New Run Script Phase"
4. Rename the phase to "Sign Sparkle Framework"
5. Make sure this phase runs after the "Copy Bundle Resources" phase
6. In the script field, enter:
   ```bash
   "${SRCROOT}/ClientNote/Resources/sign_sparkle.sh"
   ```

### 3. Configure Code Signing

1. In Xcode, select the ClientNote target
2. Go to the "Signing & Capabilities" tab
3. Make sure "Automatically manage signing" is checked
4. Select your team
5. Change the "Signing Certificate" from "Sign to Run Locally" to "Apple Development" or "Apple Distribution" (depending on whether you're creating a development or distribution build)

### 4. Build and Archive

1. Clean the build folder (Xcode menu → Product → Clean Build Folder)
2. Build and archive your app
3. Validate the archive

## Troubleshooting

If you encounter issues with the Sparkle framework components not being properly signed, try the following:

1. Check the build log for any errors related to the signing script
2. Verify that the entitlements files are included in the "Copy Bundle Resources" phase
3. Make sure the signing script is running after the "Copy Bundle Resources" phase
4. Check that the code signing identity is properly set in Xcode

## Alternative Approaches

If you continue to have issues with Sparkle and app sandbox, consider the following alternatives:

1. Use the Mac App Store for distribution, which handles updates automatically
2. Implement a custom update mechanism that works within the app sandbox constraints
3. Use a different auto-update framework that's more compatible with app sandbox 