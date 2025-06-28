#!/bin/bash
set -e

echo "🔏 Code signing llama-server with sandbox entitlements..."

# Paths
LLAMA_SERVER_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Resources/llama-server"
ENTITLEMENTS_PATH="${SRCROOT}/ClientNote/Resources/llama-server.entitlements"

# Check if llama-server exists
if [ ! -f "$LLAMA_SERVER_PATH" ]; then
    echo "❌ Error: llama-server not found at: $LLAMA_SERVER_PATH"
    exit 1
fi

# Check if entitlements file exists
if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo "❌ Error: Entitlements file not found at: $ENTITLEMENTS_PATH"
    exit 1
fi

echo "📝 Signing llama-server with:"
echo "  Binary: $LLAMA_SERVER_PATH"
echo "  Entitlements: $ENTITLEMENTS_PATH"
echo "  Identity: $EXPANDED_CODE_SIGN_IDENTITY"

# Code sign the binary with sandbox entitlements
codesign \
    --force \
    --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
    --entitlements "$ENTITLEMENTS_PATH" \
    --options runtime \
    --timestamp \
    "$LLAMA_SERVER_PATH"

# Verify the signature
echo "✅ Verifying signature..."
codesign --verify --deep --strict "$LLAMA_SERVER_PATH"

# Display entitlements to confirm sandbox is enabled
echo "📋 Verifying sandbox entitlement..."
codesign --display --entitlements - "$LLAMA_SERVER_PATH" | grep -A 1 "com.apple.security.app-sandbox"

echo "✅ llama-server successfully code signed with sandbox entitlements!" 