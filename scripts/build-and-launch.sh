#!/bin/bash
set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# App package name
PACKAGE_NAME="com.amaruwear"
ACTIVITY_NAME=".MainActivity"

# Parse command line arguments
CLEAR_DATA=false
for arg in "$@"; do
    case $arg in
        --clear-data)
            CLEAR_DATA=true
            shift
            ;;
        *)
            ;;
    esac
done

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Amaru Wear - Build & Launch Script               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print step
print_step() {
    echo -e "\n${GREEN}▶ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ Error: $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ Warning: $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Check environment setup
print_step "Checking prerequisites..."

if [ -z "$ANDROID_HOME" ] || [ -z "$NDK_HOME" ]; then
  print_warning "Environment not configured, running setup..."
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  bash "$SCRIPT_DIR/setup.sh" || exit 1
  # Set environment directly (setup.sh output shows values)
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [ -d "$ANDROID_HOME/ndk" ]; then
    export NDK_HOME="$ANDROID_HOME/ndk/$(ls "$ANDROID_HOME/ndk" | head -1)"
  fi
fi

# Check for Gradle wrapper
if [ ! -f "gradlew" ]; then
    print_error "Gradle wrapper not found"
    echo "Please run: ./install-gradle.sh"
    exit 1
fi

# Check for local.properties
if [ ! -f "local.properties" ]; then
    print_error "local.properties not found"
    echo "Please run: ./install-gradle.sh"
    exit 1
fi

if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    print_error "ANDROID_HOME or ANDROID_SDK_ROOT not set"
    echo "Please set ANDROID_HOME to your Android SDK path"
    echo "Example: export ANDROID_HOME=\$HOME/Library/Android/sdk"
    exit 1
fi

# Set ANDROID_SDK_ROOT if only ANDROID_HOME is set
if [ -z "$ANDROID_SDK_ROOT" ] && [ -n "$ANDROID_HOME" ]; then
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
fi

# Set adb and emulator paths
ADB="${ANDROID_SDK_ROOT}/platform-tools/adb"
EMULATOR="${ANDROID_SDK_ROOT}/emulator/emulator"

# Check if adb exists
if [ ! -f "$ADB" ]; then
    print_error "adb not found at $ADB"
    exit 1
fi

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    print_error "Rust/Cargo not found. Install from https://rustup.rs/"
    exit 1
fi

print_success "Prerequisites OK"

# Check for cargo-ndk
print_step "Checking cargo-ndk..."
if ! command -v cargo-ndk &> /dev/null; then
    print_warning "cargo-ndk not found. Installing..."
    cargo install cargo-ndk
fi
print_success "cargo-ndk available"

# Build Rust library
print_step "Building Rust library for Android..."
cd rust

echo "  → Building for arm64-v8a..."
cargo ndk -t arm64-v8a -o ../app/src/main/jniLibs --link-libcxx-shared build --release 2>&1 | grep -E "(Compiling|Finished|error)" || true

echo "  → Building for armeabi-v7a..."
cargo ndk -t armeabi-v7a -o ../app/src/main/jniLibs --link-libcxx-shared build --release 2>&1 | grep -E "(Compiling|Finished|error)" || true

cd ..

# Verify libraries were created
if [ ! -f "app/src/main/jniLibs/arm64-v8a/libamaru_wear.so" ]; then
    print_error "Failed to build Rust library for arm64-v8a"
    exit 1
fi

print_success "Rust library built successfully"

# Build Android APK
print_step "Building Android APK..."

# Clean first to ensure jniLibs are properly packaged
./gradlew clean >/dev/null 2>&1

./gradlew assembleDebug 2>&1 | grep -E "(BUILD|FAILED|error|warning:.*MainActivity)" || true

if [ ! -f "app/build/outputs/apk/debug/app-debug.apk" ]; then
    print_error "Failed to build APK"
    exit 1
fi

print_success "APK built successfully"

# Check for running emulators
print_step "Checking for running emulators..."
RUNNING_DEVICES=$("$ADB" devices | grep -v "List" | grep "device" | awk '{print $1}')

if [ -z "$RUNNING_DEVICES" ]; then
    print_warning "No emulator running. Attempting to start one..."
    
    # Check if emulator command exists
    if [ ! -f "$EMULATOR" ]; then
        print_error "Emulator not found. Please start a WearOS emulator manually."
        echo ""
        echo "To start an emulator:"
        echo "  1. Open Android Studio"
        echo "  2. Tools → Device Manager"
        echo "  3. Start a Wear OS emulator"
        echo ""
        echo "Or from command line:"
        echo "  \$ANDROID_SDK_ROOT/emulator/emulator -list-avds"
        echo "  \$ANDROID_SDK_ROOT/emulator/emulator -avd <name>"
        exit 1
    fi
    
    # List available AVDs
    AVDS=$("$EMULATOR" -list-avds 2>/dev/null)
    
    if [ -z "$AVDS" ]; then
        print_error "No Android Virtual Devices (AVDs) found"
        echo ""
        echo "You need a WearOS emulator to run this app!"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Would you like to create a WearOS emulator now?"
        echo "This will download ~600MB and take a few minutes."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        read -p "Create WearOS emulator? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "Please create a WearOS emulator manually and try again"
            exit 1
        fi
        
        # Run the create emulator script
        if [ -f "./create-wearos-emulator.sh" ]; then
            ./create-wearos-emulator.sh
            if [ $? -ne 0 ]; then
                print_error "Failed to create WearOS emulator"
                exit 1
            fi
            # Refresh AVD list
            AVDS=$("$EMULATOR" -list-avds 2>/dev/null)
        else
            print_error "create-wearos-emulator.sh not found"
            exit 1
        fi
    fi
    
    # Find a Wear OS AVD
    WEAR_AVD=$(echo "$AVDS" | grep -i "wear" | head -1)
    
    if [ -z "$WEAR_AVD" ]; then
        print_error "No Wear OS AVD found!"
        echo ""
        echo "Available AVDs:"
        echo "$AVDS"
        echo ""
        echo "Please create a WearOS emulator:"
        echo "  ./create-wearos-emulator.sh"
        echo ""
        echo "Or manually in Android Studio:"
        echo "  Tools → Device Manager → Create Device → Wear OS"
        exit 1
    fi
    
    echo "Found Wear OS AVD: $WEAR_AVD"
    
    echo "Starting emulator: $WEAR_AVD"
    echo "(This may take a minute...)"
    "$EMULATOR" -avd "$WEAR_AVD" &> /dev/null &
    EMULATOR_PID=$!
    
    # Wait for emulator to boot
    echo -n "Waiting for emulator to boot"
    for i in {1..60}; do
        sleep 2
        echo -n "."
        BOOT_COMPLETE=$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')
        if [ "$BOOT_COMPLETE" = "1" ]; then
            echo ""
            print_success "Emulator booted successfully"
            break
        fi
        if [ $i -eq 60 ]; then
            echo ""
            print_error "Emulator failed to boot in time"
            exit 1
        fi
    done
else
    DEVICE_COUNT=$(echo "$RUNNING_DEVICES" | wc -l | xargs)
    print_success "Found $DEVICE_COUNT running device(s)"
    
    # Check if running device is WearOS
    FIRST_DEVICE=$(echo "$RUNNING_DEVICES" | head -1)
    DEVICE_PRODUCT=$("$ADB" -s "$FIRST_DEVICE" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
    
    if ! echo "$DEVICE_PRODUCT" | grep -iq "wear"; then
        print_warning "Running device may not be a WearOS device: $DEVICE_PRODUCT"
        echo ""
        echo "This app requires a WearOS emulator!"
        echo "If installation fails, please:"
        echo "  1. Stop current emulator"
        echo "  2. Run: ./create-wearos-emulator.sh"
        echo "  3. Run: make launch"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled. Please start a WearOS emulator."
            exit 1
        fi
    fi
fi

# Get the first device
DEVICE=$(echo "$RUNNING_DEVICES" | head -1)
echo "Using device: $DEVICE"

# Clear ledger/consensus data before uninstall (while package is still registered)
if [ "$CLEAR_DATA" = true ]; then
    print_step "Clearing ledger/consensus data..."
    "$ADB" -s "$DEVICE" shell pm clear "$PACKAGE_NAME" 2>/dev/null || true
    print_success "Ledger/consensus data cleared"
fi

# Uninstall old version if exists
print_step "Uninstalling old version (if exists)..."
"$ADB" -s "$DEVICE" uninstall "$PACKAGE_NAME" 2>/dev/null || true

# Install APK
print_step "Installing APK..."
"$ADB" -s "$DEVICE" install app/build/outputs/apk/debug/app-debug.apk

if [ $? -ne 0 ]; then
    print_error "Failed to install APK"
    exit 1
fi

print_success "APK installed successfully"

# Launch the app
print_step "Launching app..."
"$ADB" -s "$DEVICE" shell am start -n "${PACKAGE_NAME}/${ACTIVITY_NAME}"

if [ $? -ne 0 ]; then
    print_error "Failed to launch app"
    exit 1
fi

print_success "App launched successfully!"

# Show logs
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Build and launch complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "📱 App is now running on the WearOS emulator!"
echo "📋 Watching logs for bootstrap progress..."
echo "   (Press Ctrl+C to stop)"
echo ""

# Clear old logs and show live logs automatically
"$ADB" logcat -c
sleep 1
"$ADB" logcat | grep --color=auto -E "(AmaruWear|amaruwear|AndroidRuntime.*${PACKAGE_NAME})"
