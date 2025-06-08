#!/bin/bash
set -e  # Exit on error

echo "🦙 Building static llama-server for Apple Silicon..."

# Clean previous builds
rm -rf build_static
mkdir build_static
cd build_static

# Configure CMake for static build with Apple Silicon optimizations
# Use RelWithDebInfo to include debug symbols for App Store dSYM requirements
cmake .. \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DLLAMA_STATIC=ON \
    -DLLAMA_NATIVE=OFF \
    -DLLAMA_METAL=ON \
    -DLLAMA_ACCELERATE=ON \
    -DLLAMA_BUILD_SERVER=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="14.0" \
    -DCMAKE_EXE_LINKER_FLAGS="-framework Metal -framework Foundation -framework Accelerate" \
    -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DCMAKE_CXX_FLAGS="-O3 -g"

# Build with all available cores
cmake --build . --config RelWithDebInfo -j$(sysctl -n hw.logicalcpu)

# Extract debug symbols for App Store dSYM requirements
if [ -f "bin/llama-server" ]; then
    echo "📝 Extracting debug symbols..."
    dsymutil bin/llama-server -o bin/llama-server.dSYM
    
    echo "🔏 Code signing binary..."
    # Sign with development certificate (will be re-signed during Xcode build)
    codesign --force --sign - bin/llama-server
    
    echo "✅ Binary built with debug symbols and code signing!"
    
    # Show file info
    file bin/llama-server
    ls -la bin/llama-server*
else
    echo "❌ Error: llama-server binary not found!"
    exit 1
fi

echo "✅ Build complete!" 