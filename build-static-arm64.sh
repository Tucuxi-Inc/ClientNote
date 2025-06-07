#!/bin/bash
set -e  # Exit on error

echo "🦙 Building static llama-server for Apple Silicon..."

# Clean previous builds
rm -rf build_static
mkdir build_static
cd build_static

# Configure CMake for static build with Apple Silicon optimizations
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_STATIC=ON \
    -DLLAMA_NATIVE=OFF \
    -DLLAMA_METAL=ON \
    -DLLAMA_ACCELERATE=ON \
    -DLLAMA_BUILD_SERVER=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="11.0" \
    -DCMAKE_EXE_LINKER_FLAGS="-framework Metal -framework Foundation -framework Accelerate" \
    -DCMAKE_FIND_LIBRARY_SUFFIXES=".a" \
    -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG"

# Build with all available cores
cmake --build . --config Release -j$(sysctl -n hw.logicalcpu)

echo "✅ Build complete!" 