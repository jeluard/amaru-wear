#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Amaru Wear - Build & Deploy Script               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

print_step() {
    echo -e "\n${GREEN}▶ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ Error: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ Warning: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Environment setup
print_step "Checking environment..."

if [ -z "$ANDROID_HOME" ] || [ -z "$NDK_HOME" ]; then
  print_warning "Environment not configured, running setup..."
  bash "$SCRIPT_DIR/setup.sh" || exit 1
  # Source environment
  if [ -f "$HOME/.bashrc" ]; then source "$HOME/.bashrc"; fi
  if [ -f "$HOME/.zshrc" ]; then source "$HOME/.zshrc"; fi
fi

# Check for adb
if ! command -v adb &> /dev/null; then
  print_error "adb not found in PATH"
  echo "Add to PATH: export PATH=\"\$ANDROID_HOME/platform-tools:\$PATH\""
  exit 1
fi
print_success "adb found"

# Check device
print_step "Checking for connected device..."
DEVICES=$(adb devices | grep -v "^$" | tail -n +2 | grep -v "List of attached devices")
if [ -z "$DEVICES" ]; then
  print_error "No devices found!"
  echo ""
  echo "Options:"
  echo "  1. Enable WiFi ADB on your watch:"
  echo "     Settings > Developer Options > Debug over WiFi"
  echo "  2. Connect: adb connect <watch_ip>:5555"
  echo "  3. Run this script again"
  exit 1
fi
echo "$DEVICES" | while read -r device; do
  print_success "Device: $device"
done

# Build Rust
print_step "Building Rust library..."
cd "$PROJECT_DIR/rust"
cargo-ndk -t arm64-v8a -t armeabi-v7a build --release 2>&1 | tail -20
print_success "Rust build complete"

# Copy .so files
print_step "Packaging native libraries..."
mkdir -p "$PROJECT_DIR/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$PROJECT_DIR/app/src/main/jniLibs/armeabi-v7a"
cp "$PROJECT_DIR/rust/target/aarch64-linux-android/release/libamaru_wear.so" \
   "$PROJECT_DIR/app/src/main/jniLibs/arm64-v8a/"
cp "$PROJECT_DIR/rust/target/armv7-linux-androideabi/release/libamaru_wear.so" \
   "$PROJECT_DIR/app/src/main/jniLibs/armeabi-v7a/"
print_success "Libraries packaged"

# Build APK
print_step "Building Android APK..."
cd "$PROJECT_DIR"
./gradlew clean assembleDebug 2>&1 | grep -E "(BUILD|:app:|FAILED)" || echo "Building..."
if [ ${PIPESTATUS[0]} -ne 0 ]; then
  print_error "Build failed!"
  exit 1
fi
print_success "APK built"

APK_PATH="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"

# Install APK
print_step "Installing APK on device..."
adb install -r "$APK_PATH"
print_success "APK installed"

# Launch app
print_step "Launching app..."
adb shell am start -n "com.amaruwear/.MainActivity"
print_success "App launched"

# Show logs
print_step "Showing logs (Ctrl+C to stop)..."
echo ""
adb logcat --clear
adb logcat | grep -E "(AmaruWear|amaru_wear|BOOTSTRAP|SYNC|TIP)" || true

