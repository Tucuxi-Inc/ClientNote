#!/bin/bash

# Subscription Testing Helper Script for ClientNote
# This script helps automate some testing scenarios

echo "🧪 ClientNote Subscription Testing Helper"
echo "=========================================="

# Function to check if Xcode is running
check_xcode() {
    if pgrep -x "Xcode" > /dev/null; then
        echo "✅ Xcode is running"
        return 0
    else
        echo "❌ Xcode is not running. Please start Xcode first."
        return 1
    fi
}

# Function to check if simulator is running
check_simulator() {
    if pgrep -x "Simulator" > /dev/null; then
        echo "✅ Simulator is running"
        return 0
    else
        echo "❌ Simulator is not running. Please start the iOS Simulator."
        return 1
    fi
}

# Function to display testing checklist
show_checklist() {
    echo ""
    echo "📋 Pre-Testing Checklist:"
    echo "========================"
    echo "□ Xcode project is open"
    echo "□ StoreKit configuration file is selected in scheme"
    echo "□ App is built and running in simulator/device"
    echo "□ Internet connection is available"
    echo "□ Test Apple ID is signed in (for sandbox testing)"
    echo ""
}

# Function to show testing scenarios
show_scenarios() {
    echo "🎯 Key Testing Scenarios:"
    echo "========================"
    echo "1. Product Loading Test"
    echo "   - Launch app → Settings → Subscription"
    echo "   - Verify all products load correctly"
    echo "   - Check prices and descriptions"
    echo ""
    echo "2. Network Error Test"
    echo "   - Disable internet connection"
    echo "   - Navigate to Subscription view"
    echo "   - Verify error message and retry button"
    echo ""
    echo "3. Purchase Flow Test"
    echo "   - Select each subscription tier"
    echo "   - Complete purchase process"
    echo "   - Verify free trial periods"
    echo ""
    echo "4. Privacy Policy & Terms Test"
    echo "   - Click 'Terms of Use' link"
    echo "   - Verify opens: https://bit.ly/TucuxiTermsoUse"
    echo "   - Click 'Privacy Policy' link"
    echo "   - Verify opens: https://bit.ly/TucuxiPrivacyPolicy"
    echo ""
    echo "5. Debug Testing (DEBUG builds only)"
    echo "   - Use simulation buttons to test different states"
    echo "   - Test purchase reset functionality"
    echo ""
}

# Function to show StoreKit testing setup
show_storekit_setup() {
    echo "⚙️  StoreKit Testing Setup:"
    echo "=========================="
    echo "1. In Xcode, edit your scheme"
    echo "2. Go to Run → Options"
    echo "3. Set StoreKit Configuration to 'ClientNoteConfiguration.storekit'"
    echo "4. Enable 'StoreKit Testing in Xcode'"
    echo ""
    echo "To test error conditions:"
    echo "- In Xcode menu: Debug → StoreKit → Manage Transactions"
    echo "- Enable various error conditions for testing"
    echo ""
}

# Function to show common issues
show_common_issues() {
    echo "🔧 Common Issues & Solutions:"
    echo "============================"
    echo "Issue: Products not loading"
    echo "Solution: Check internet, verify StoreKit config, restart app"
    echo ""
    echo "Issue: Purchase fails"
    echo "Solution: Check test account, verify payment method, check logs"
    echo ""
    echo "Issue: Links don't work"
    echo "Solution: Verify URLs are correct, check network connection"
    echo ""
    echo "Issue: Debug options not visible"
    echo "Solution: Ensure you're running a DEBUG build, not RELEASE"
    echo ""
}

# Main menu
show_menu() {
    echo ""
    echo "Choose an option:"
    echo "1. Show pre-testing checklist"
    echo "2. Show testing scenarios"
    echo "3. Show StoreKit setup instructions"
    echo "4. Show common issues & solutions"
    echo "5. Run environment check"
    echo "6. Exit"
    echo ""
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1) show_checklist ;;
        2) show_scenarios ;;
        3) show_storekit_setup ;;
        4) show_common_issues ;;
        5) 
            echo ""
            echo "🔍 Environment Check:"
            echo "===================="
            check_xcode
            check_simulator
            echo ""
            echo "Network connectivity:"
            if ping -c 1 google.com &> /dev/null; then
                echo "✅ Internet connection is working"
            else
                echo "❌ No internet connection detected"
            fi
            ;;
        6) 
            echo "Happy testing! 🚀"
            exit 0 
            ;;
        *) 
            echo "Invalid choice. Please try again."
            ;;
    esac
}

# Main loop
while true; do
    show_menu
    echo ""
    read -p "Press Enter to continue..."
    clear
done 