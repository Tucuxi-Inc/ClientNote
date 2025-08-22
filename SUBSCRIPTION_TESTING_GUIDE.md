# Subscription Testing Guide for ClientNote

This guide provides comprehensive instructions for testing the subscription functionality in ClientNote before App Store submission.

## Prerequisites

1. **Xcode with StoreKit Configuration**
   - Ensure `ClientNoteConfiguration.storekit` is properly configured
   - All subscription products are defined with correct IDs
   - Free trial periods are configured correctly

2. **Test Environment Setup**
   - Use Xcode's StoreKit testing environment
   - Create sandbox test accounts in App Store Connect
   - Ensure proper signing certificates are in place

## Testing Scenarios

### 1. Product Loading Tests

**Test Case 1.1: Successful Product Loading**
- Launch app in fresh state
- Navigate to Subscription view
- Verify all subscription products load correctly
- Check that prices display properly
- Confirm product descriptions are accurate

**Test Case 1.2: Network Error Handling**
- Disable internet connection
- Launch app and navigate to Subscription view
- Verify error message displays: "Network error: Please check your internet connection and try again."
- Test retry button functionality
- Re-enable internet and verify products load after retry

**Test Case 1.3: App Store Connection Issues**
- Use Xcode's StoreKit testing with "Load Products" error enabled
- Verify appropriate error message displays
- Test retry functionality

### 2. Subscription Purchase Tests

**Test Case 2.1: Weekly Subscription Purchase**
- Select 1-Week Plan
- Complete purchase flow
- Verify 3-day free trial is applied
- Check subscription status updates correctly
- Confirm access to premium features

**Test Case 2.2: Monthly Subscription Purchase**
- Select 1-Month Plan
- Complete purchase flow
- Verify 7-day free trial is applied
- Check subscription status and expiration date

**Test Case 2.3: Quarterly Subscription Purchase**
- Select 3-Month Plan
- Complete purchase flow
- Verify 7-day free trial is applied
- Check subscription status and expiration date

**Test Case 2.4: Yearly Subscription Purchase**
- Select 1-Year Plan
- Complete purchase flow
- Verify 7-day free trial is applied
- Check subscription status and expiration date

**Test Case 2.5: One-Time Purchase**
- Select One-Time Purchase option
- Complete purchase flow
- Verify permanent access is granted
- Check that no expiration date is set

### 3. Free Trial Tests

**Test Case 3.1: Free Trial Eligibility**
- Fresh install/reset app
- Verify free trial is offered for each subscription type
- Complete trial signup
- Verify trial period is correctly calculated and displayed

**Test Case 3.2: Free Trial Expiration**
- Use StoreKit testing to simulate trial expiration
- Verify app correctly handles trial expiration
- Check that premium features are restricted after expiration
- Verify user is prompted to subscribe

**Test Case 3.3: Multiple Trial Prevention**
- Complete a free trial for one subscription type
- Attempt to start another trial for the same type
- Verify that Apple's StoreKit prevents multiple trials
- Test with different subscription tiers

### 4. Subscription Management Tests

**Test Case 4.1: Subscription Upgrade**
- Start with weekly subscription
- Upgrade to monthly, quarterly, then yearly
- Verify upgrade process works correctly
- Check that billing is handled properly by Apple

**Test Case 4.2: Subscription Downgrade**
- Start with yearly subscription
- Downgrade to quarterly, monthly, then weekly
- Verify downgrade process and timing
- Check that access continues until current period ends

**Test Case 4.3: Subscription Cancellation**
- Subscribe to any plan
- Cancel subscription through App Store settings
- Verify app correctly detects cancellation
- Check that access continues until expiration
- Verify renewal prompts appear appropriately

### 5. Purchase Restoration Tests

**Test Case 5.1: Successful Restoration**
- Make purchase on one device
- Install app on second device (or reset first device)
- Use "Restore Purchases" button
- Verify purchases are correctly restored
- Check that access is properly granted

**Test Case 5.2: No Purchases to Restore**
- Fresh install with no previous purchases
- Use "Restore Purchases" button
- Verify appropriate message is displayed
- Check that no false access is granted

### 6. Error Handling Tests

**Test Case 6.1: Purchase Cancellation**
- Start purchase process
- Cancel during payment flow
- Verify app handles cancellation gracefully
- Check that no partial access is granted

**Test Case 6.2: Payment Failure**
- Use test account with insufficient funds (if available)
- Attempt purchase
- Verify error handling and user feedback
- Check that app state remains consistent

**Test Case 6.3: Network Interruption During Purchase**
- Start purchase process
- Disable network mid-transaction
- Verify app handles interruption properly
- Re-enable network and check transaction status

### 7. Privacy Policy and Terms of Use Tests

**Test Case 7.1: Link Functionality**
- Navigate to Subscription view
- Click "Terms of Use" link
- Verify link opens correctly to: https://bit.ly/TucuxiTermsoUse
- Click "Privacy Policy" link  
- Verify link opens correctly to: https://bit.ly/TucuxiPrivacyPolicy

**Test Case 7.2: Link Accessibility**
- Test links with VoiceOver enabled
- Verify links are properly announced
- Check that links are keyboard accessible

### 8. UI/UX Tests

**Test Case 8.1: Subscription Display**
- Verify all required information is displayed:
  - Subscription title
  - Length of subscription
  - Price of subscription
  - Free trial information
  - Auto-renewal information
  - Privacy Policy and Terms of Use links

**Test Case 8.2: Current Subscription Indication**
- Subscribe to any plan
- Verify current subscription is clearly marked
- Check that upgrade/downgrade options are appropriately labeled
- Verify "CURRENT" badge displays correctly

**Test Case 8.3: Loading States**
- Verify loading indicators during product loading
- Check loading states during purchase process
- Ensure UI remains responsive during operations

### 9. Edge Cases

**Test Case 9.1: App Store Maintenance**
- Test behavior when App Store is unavailable
- Verify graceful degradation
- Check retry mechanisms

**Test Case 9.2: Clock Changes**
- Change device time/timezone
- Verify subscription status calculations remain accurate
- Check trial period calculations

**Test Case 9.3: App Updates**
- Install app update while subscription is active
- Verify subscription status is maintained
- Check that all features remain accessible

## Testing Tools

### Xcode StoreKit Testing
1. Enable StoreKit testing in scheme
2. Use `ClientNoteConfiguration.storekit` file
3. Test various error conditions using StoreKit settings

### App Store Connect Sandbox
1. Create sandbox test accounts
2. Test real purchase flows
3. Verify receipt validation

### Device Testing
1. Test on multiple device types (Mac, different screen sizes)
2. Test with different iOS/macOS versions
3. Verify accessibility features

## Pre-Submission Checklist

- [ ] All subscription products load correctly
- [ ] Privacy Policy and Terms of Use links are functional
- [ ] Free trials work as expected
- [ ] Purchase flows complete successfully
- [ ] Error handling is robust and user-friendly
- [ ] Subscription management works correctly
- [ ] Purchase restoration functions properly
- [ ] UI displays all required information
- [ ] Accessibility features work correctly
- [ ] App handles network issues gracefully
- [ ] All edge cases have been tested

## Common Issues and Solutions

### Products Not Loading
- Check internet connection
- Verify StoreKit configuration
- Ensure product IDs match exactly
- Check App Store Connect configuration

### Purchase Failures
- Verify test account setup
- Check payment method configuration
- Ensure proper error handling is implemented
- Test with different account types

### Trial Issues
- Verify trial periods in StoreKit configuration
- Check that Apple's trial restrictions are respected
- Test trial expiration handling

## Notes for App Store Review

- Ensure all required subscription information is visible in the app binary
- Privacy Policy and Terms of Use links must be functional
- Error messages should be user-friendly and actionable
- The app should handle all error conditions gracefully
- Subscription management should be intuitive and clear 