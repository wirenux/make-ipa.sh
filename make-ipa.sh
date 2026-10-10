#!/bin/bash

set -e

echo "================================="
echo "       iOS IPA Builder"
echo "================================="

# Ask for project path
read -r -p "Enter project path: " PROJECT_PATH

# Remove surrounding quotes
PROJECT_PATH="${PROJECT_PATH%\"}"
PROJECT_PATH="${PROJECT_PATH#\"}"
PROJECT_PATH="${PROJECT_PATH%\'}"
PROJECT_PATH="${PROJECT_PATH#\'}"

# Expand escaped spaces
PROJECT_PATH="${PROJECT_PATH//\\ / }"

# Expand ~
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

if [ ! -e "$PROJECT_PATH" ]; then
    echo "Error: Project path does not exist."
    exit 1
fi

# Ask for scheme/app name
read -r -p "Enter app/scheme name: " SCHEME

if [ -z "$SCHEME" ]; then
    echo "Error: Scheme name cannot be empty."
    exit 1
fi

# Locate workspace or project
if [[ "$PROJECT_PATH" == *.xcworkspace ]]; then
    BUILD_TYPE="workspace"
    PROJECT_DIR="$(dirname "$PROJECT_PATH")"
    PROJECT_FILE="$PROJECT_PATH"

elif [[ "$PROJECT_PATH" == *.xcodeproj ]]; then
    BUILD_TYPE="project"
    PROJECT_DIR="$(dirname "$PROJECT_PATH")"
    PROJECT_FILE="$PROJECT_PATH"

elif [ -d "$PROJECT_PATH" ]; then
    PROJECT_DIR="$PROJECT_PATH"

    WORKSPACE=$(find "$PROJECT_DIR" \
        -maxdepth 1 -name "*.xcworkspace" \
        -print -quit)

    XCODEPROJ=$(find "$PROJECT_DIR" \
        -maxdepth 1 -name "*.xcodeproj" \
        -print -quit)

    if [ -n "$WORKSPACE" ]; then
        BUILD_TYPE="workspace"
        PROJECT_FILE="$WORKSPACE"
    elif [ -n "$XCODEPROJ" ]; then
        BUILD_TYPE="project"
        PROJECT_FILE="$XCODEPROJ"
    else
        echo "Error: No .xcworkspace or .xcodeproj found."
        exit 1
    fi
else
    echo "Error: Invalid project path."
    exit 1
fi

# Temporary build directory
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ipa-build.XXXXXX")
trap 'rm -rf "$BUILD_DIR"' EXIT

# Output IPA
OUTPUT_IPA="$PROJECT_DIR/$SCHEME.ipa"

echo ""
echo "Project: $PROJECT_FILE"
echo "Scheme:  $SCHEME"
echo "Output:  $OUTPUT_IPA"
echo ""
echo "Building for iPhone..."

# Build signed app for a real iOS device
if [ "$BUILD_TYPE" = "workspace" ]; then
    xcodebuild \
        -workspace "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -sdk iphoneos \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "$BUILD_DIR" \
        build
else
    xcodebuild \
        -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -sdk iphoneos \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "$BUILD_DIR" \
        build
fi

# Find the built application
APP_PATH="$BUILD_DIR/Build/Products/Debug-iphoneos/$SCHEME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Built .app not found at:"
    echo "$APP_PATH"
    echo "Check your scheme and build settings."
    exit 1
fi

# Package IPA
echo "Packaging IPA..."

PACKAGE_DIR="$BUILD_DIR/package"
mkdir -p "$PACKAGE_DIR/Payload"
cp -R "$APP_PATH" "$PACKAGE_DIR/Payload/"

(
    cd "$PACKAGE_DIR"
    /usr/bin/ditto -c -k --sequesterRsrc \
        --keepParent Payload "$OUTPUT_IPA"
)

echo ""
echo "================================="
echo "IPA created successfully!"
echo "$OUTPUT_IPA"
echo "================================="
