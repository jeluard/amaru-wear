#!/bin/bash

# Build script for Rust library for Android

set -e

# Source Android environment if not already set
if [ -z "$ANDROID_HOME" ]; then
    if [ -f "./setup-android-env.sh" ]; then
        echo "Setting up Android environment..."
        source ./setup-android-env.sh
    else
        echo "Error: ANDROID_HOME not set and setup-android-env.sh not found"
        exit 1
    fi
fi

echo "Building Rust library for Android..."

# Install cargo-ndk if not already installed
if ! command -v cargo-ndk &> /dev/null; then
    echo "Installing cargo-ndk..."
    cargo install cargo-ndk
fi

# Build for Android targets
cd rust

echo "Building for arm64-v8a..."
cargo ndk -t arm64-v8a -o ../app/src/main/jniLibs --link-libcxx-shared build --release

echo "Building for armeabi-v7a..."
cargo ndk -t armeabi-v7a -o ../app/src/main/jniLibs --link-libcxx-shared build --release

cd ..

# Verify libc++_shared.so is present (cargo-ndk should copy it, but verify)
echo "Verifying libc++ libraries..."
if [ ! -f "app/src/main/jniLibs/arm64-v8a/libc++_shared.so" ]; then
    echo "⚠️  libc++_shared.so missing for arm64-v8a, copying from NDK..."
    cp "$ANDROID_HOME/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" \
       app/src/main/jniLibs/arm64-v8a/
fi

if [ ! -f "app/src/main/jniLibs/armeabi-v7a/libc++_shared.so" ]; then
    echo "⚠️  libc++_shared.so missing for armeabi-v7a, copying from NDK..."
    cp "$ANDROID_HOME/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/arm-linux-androideabi/libc++_shared.so" \
       app/src/main/jniLibs/armeabi-v7a/
fi

echo "✓ libc++ libraries verified"
echo ""
echo "Rust library built successfully!"
echo "Libraries are in app/src/main/jniLibs/"
