# Mac App Store Distribution Guide

This guide provides instructions on how to prepare your app for distribution on the Mac App Store.

## Overview

The Mac App Store provides a convenient way to distribute your app to users, with automatic updates and a trusted distribution channel. This guide will help you prepare your app for submission to the Mac App Store.

## Prerequisites

1. An Apple Developer Program membership ($99/year)
2. Xcode 15 or later
3. App Store Connect account set up

## Steps to Prepare Your App for Mac App Store

### 1. Remove Sparkle Framework

We've already removed the Sparkle framework from the code, as it's not needed for Mac App Store distribution. The Mac App Store handles updates automatically.

### 2. Configure App for Mac App Store

1. Open your Xcode project
2. Select the ClientNote target
3. Go to the "Signing & Capabilities" tab
4. Make sure "Automatically manage signing" is checked
5. Select your team
6. Change the "Signing Certificate" to "Apple Distribution"
7. Make sure the Bundle Identifier is unique and properly formatted (e.g., ai.tucuxi.ClientNote)

### 3. Update Info.plist

1. Open Info.plist
2. Add or update the following keys:
   - `ITSAppUsesNonExemptEncryption` (Boolean): Set to `NO` if your app doesn't use encryption
   - `LSApplicationCategoryType` (String): Set to the appropriate category (e.g., `public.app-category.productivity`)
   - `CFBundleShortVersionString` (String): Set to your app's version number (e.g., `1.0.0`)
   - `CFBundleVersion` (String): Set to your app's build number (e.g., `1`)

### 4. Create App Store Connect Record

1. Log in to [App Store Connect](https://appstoreconnect.apple.com/)
2. Click on "My Apps"
3. Click the "+" button and select "New App"
4. Fill in the required information:
   - Platform: macOS
   - Name: ClientNote
   - Bundle ID: Select your app's bundle identifier
   - SKU: A unique identifier for your app (e.g., `clientnote2024`)
   - User Access: Full Access

### 5. Prepare App Store Listing

1. In App Store Connect, select your app
2. Go to the "App Information" tab
3. Fill in the required information:
   - Description
   - Keywords
   - Support URL
   - Marketing URL (optional)
   - Privacy Policy URL
   - Category
   - Rating

### 6. Prepare App Store Screenshots

1. Take screenshots of your app in different sizes:
   - 1280 x 800 (16:10)
   - 1440 x 900 (16:10)
   - 2560 x 1600 (16:10)
   - 2880 x 1800 (16:10)
2. Upload the screenshots to App Store Connect

### 7. Archive and Upload Your App

1. In Xcode, select "Any Mac" as the build target
2. Select Product > Archive
3. In the Archives window, click "Distribute App"
4. Select "App Store Connect" and click "Next"
5. Select "Upload" and click "Next"
6. Select "Automatically manage signing" and click "Next"
7. Click "Upload"

### 8. Submit for Review

1. In App Store Connect, go to your app's "App Store" tab
2. Click on the "+" button next to "Version" and enter your version number
3. Fill in the "What's New in This Version" section
4. Upload your app's build
5. Fill in the "App Privacy" section
6. Click "Submit for Review"

## Troubleshooting

If you encounter issues during the submission process, check the following:

1. Make sure your app's bundle identifier matches the one in App Store Connect
2. Verify that your app's version and build numbers are correct
3. Check that all required information in App Store Connect is filled in
4. Ensure your app complies with Apple's App Store Review Guidelines

## Additional Resources

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Xcode Help](https://help.apple.com/xcode/) 