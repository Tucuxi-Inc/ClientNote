# Complete Sparkle Removal Guide

This guide provides step-by-step instructions to completely remove the Sparkle framework from your project.

## Overview

Even though we've removed the Sparkle code from your app, the framework is still being included in your build as a Swift Package dependency. This guide will help you completely remove Sparkle from your project to resolve the app sandbox validation error.

## Steps to Remove Sparkle

### 1. Remove Sparkle Package Dependency

1. Open your Xcode project
2. Select the ClientNote target
3. Go to the "Package Dependencies" tab
4. Find the Sparkle package in the list
5. Select it and click the "-" button to remove it
6. Click "Remove" to confirm

### 2. Remove Sparkle Entitlements Files

1. In the Project Navigator (the left sidebar), find the following files:
   - SparkleAutoupdate.entitlements
   - SparkleUpdater.entitlements
   - SparkleDownloader.entitlements
   - SparkleInstaller.entitlements
2. Right-click on each file and select "Delete"
3. Choose "Move to Trash" to completely remove the files

### 3. Remove "Sign Sparkle Framework" Build Phase

1. Select the ClientNote target in Xcode
2. Go to the "Build Phases" tab
3. Find the "Sign Sparkle Framework" build phase
4. Click the "-" button to remove it

### 4. Clean Up Project.pbxproj (if needed)

If the above steps don't completely remove Sparkle from your project, you may need to manually edit the project.pbxproj file:

1. Close Xcode
2. Open the ClientNote.xcodeproj/project.pbxproj file in a text editor
3. Search for "Sparkle" and remove the following sections:
   - The XCRemoteSwiftPackageReference for Sparkle
   - The XCSwiftPackageProductDependency for Sparkle
   - Any references to Sparkle in the Frameworks section
   - Any references to Sparkle entitlements files
   - The "Sign Sparkle Framework" build phase
4. Save the file and reopen Xcode

### 5. Clean and Rebuild

1. In Xcode, select Product > Clean Build Folder
2. Build your project to make sure everything still works
3. Archive your app and validate it

## Verifying Sparkle Removal

To verify that Sparkle has been completely removed from your project:

1. Archive your app
2. In the Archives window, click "Distribute App"
3. Select "App Store Connect" and click "Next"
4. Select "Upload" and click "Next"
5. Select "Automatically manage signing" and click "Next"
6. Click "Upload"
7. Check the validation results to make sure there are no more Sparkle-related errors

## Troubleshooting

If you still encounter Sparkle-related errors after following these steps:

1. Make sure you've removed all references to Sparkle in your code
2. Check that the Sparkle package is completely removed from your project
3. Verify that all Sparkle entitlements files are removed
4. Ensure the "Sign Sparkle Framework" build phase is removed
5. Clean your build folder and try again

If you continue to have issues, you may need to create a new Xcode project and migrate your code to it, making sure not to include Sparkle in the new project. 