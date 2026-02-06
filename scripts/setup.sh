#!/bin/bash
set -e

echo "🔧 Amaru Wear Setup"
echo ""

# Check OS
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  OS="linux"
else
  echo "❌ Unsupported OS: $OSTYPE"
  exit 1
fi

# Java
echo "📦 Checking Java..."
if ! command -v java &> /dev/null; then
  echo "❌ Java not found. Install JDK 11+:"
  if [ "$OS" = "macos" ]; then
    echo "  brew install openjdk@11"
  else
    echo "  sudo apt install openjdk-11-jdk"
  fi
  exit 1
fi
java_version=$(java -version 2>&1 | grep 'version' | sed 's/.*version "\([0-9]*\).*/\1/')
if [ "$java_version" -lt 11 ]; then
  echo "❌ Java 11+ required, found: $java_version"
  exit 1
fi
echo "✓ Java $java_version"

# Rust
echo "📦 Checking Rust..."
if ! command -v rustc &> /dev/null; then
  echo "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source "$HOME/.cargo/env"
fi
rustc_version=$(rustc --version | cut -d' ' -f2)
echo "✓ Rust $rustc_version"

# Android targets
echo "📦 Adding Android targets..."
rustup target add aarch64-linux-android 2>/dev/null || true
rustup target add armv7-linux-androideabi 2>/dev/null || true
echo "✓ Android targets"

# cargo-ndk
echo "📦 Installing cargo-ndk..."
cargo install cargo-ndk --quiet 2>/dev/null || true
echo "✓ cargo-ndk"

# Android SDK
echo "📦 Checking Android SDK..."
if [ -z "$ANDROID_HOME" ]; then
  if [ "$OS" = "macos" ]; then
    ANDROID_HOME="$HOME/Library/Android/sdk"
  else
    ANDROID_HOME="$HOME/Android/sdk"
  fi
fi

if [ ! -d "$ANDROID_HOME" ]; then
  echo "❌ Android SDK not found at $ANDROID_HOME"
  echo "Install Android Studio and configure SDK, or:"
  echo "  export ANDROID_HOME=~/Library/Android/sdk  (macOS)"
  echo "  export ANDROID_HOME=~/Android/sdk          (Linux)"
  exit 1
fi
echo "✓ Android SDK at $ANDROID_HOME"

# NDK
echo "📦 Checking NDK..."
NDK_VERSION=$(ls -1 "$ANDROID_HOME/ndk" 2>/dev/null | sort -V | tail -1)
if [ -z "$NDK_VERSION" ]; then
  echo "❌ NDK not found. Install via Android Studio:"
  echo "  Tools > SDK Manager > SDK Tools > NDK"
  exit 1
fi
NDK_HOME="$ANDROID_HOME/ndk/$NDK_VERSION"
echo "✓ NDK $NDK_VERSION at $NDK_HOME"

# Export for build scripts
echo ""
echo "✅ Setup complete!"
echo ""
echo "Environment variables set:"
echo "  export ANDROID_HOME=$ANDROID_HOME"
echo "  export NDK_HOME=$NDK_HOME"
echo ""
echo "Run this to persist (add to ~/.bashrc or ~/.zshrc):"
echo "  export ANDROID_HOME=$ANDROID_HOME"
echo "  export NDK_HOME=$NDK_HOME"
