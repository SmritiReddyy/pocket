#!/usr/bin/env bash
# Builds "Peekaboo.app" into ./build.
#
#   CONFIG=release|debug        default: release
#   SIGN_IDENTITY="Developer ID Application: Name (TEAMID)"
#                               default: "-" (ad-hoc, runs only on this Mac)
#   VERSION=x.y.z               default: the VERSION file
#   BUILD_NUMBER=n              default: number of commits, so it always goes up
#   BUNDLE_ID=local.Peekaboo
#   UNIVERSAL=1                 build for Apple silicon and Intel
#   DIRECT=1                    compile with swiftc instead of SwiftPM (for a broken
#                               Command Line Tools install where Package.swift won't link)
#   DIRECT_SDK=path             SDK for DIRECT=1, default: the macOS 26.5 SDK
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
VERSION="${VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"
BUNDLE_ID="${BUNDLE_ID:-local.Peekaboo}"
APP="${APP_OUTPUT:-$ROOT/build/Peekaboo.app}"
UPDATE_PUBLIC_KEY="$(tr -d '[:space:]' < "$ROOT/Support/UpdatePublicKey.txt")"
if [[ -n "$UPDATE_PUBLIC_KEY" && ! "$UPDATE_PUBLIC_KEY" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
    echo "Invalid Support/UpdatePublicKey.txt (expected base64 Ed25519 public key)" >&2
    exit 1
fi

# Use the selected Xcode's SDK. A newer Command Line Tools SDK can contain
# architectures that Xcode's linker doesn't know yet.
DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
export DEVELOPER_DIR
XCODE_SDK="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
if [[ -z "${SDKROOT:-}" && -d "$XCODE_SDK" ]]; then
    export SDKROOT="$XCODE_SDK"
fi

cd "$ROOT"
echo "› Building ($CONFIG)…"
# Keep package builds independent of Xcode's private xcbuild executable. This project uses
# SwiftPM's native build system and does not need an Xcode project or workspace.
BUILD_FLAGS=(--build-system native -c "$CONFIG")
if [[ "${DIRECT:-0}" == "1" ]]; then
    SDK="${DIRECT_SDK:-/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk}"
    [[ "$CONFIG" == "release" ]] && OPT=-O || OPT=-Onone
    BIN_DIR="$ROOT/.build/direct-$CONFIG"
    mkdir -p "$BIN_DIR/mods"
    SWIFTC=(swiftc -sdk "$SDK" -swift-version 6 -target arm64-apple-macosx14.0 "$OPT")
    "${SWIFTC[@]}" -module-name NotchKit -parse-as-library -emit-module -emit-module-path "$BIN_DIR/mods/NotchKit.swiftmodule" \
        -emit-library -static -o "$BIN_DIR/libNotchKit.a" $(find Sources/NotchKit -name '*.swift')
    "${SWIFTC[@]}" -module-name Peekaboo -I "$BIN_DIR/mods" -L "$BIN_DIR" -lNotchKit \
        -o "$BIN_DIR/Peekaboo" Sources/Peekaboo/main.swift
elif [[ "${UNIVERSAL:-0}" == "1" ]]; then
    # Multiple --arch values select XCBuild even with --build-system native.
    # Build each architecture independently so Command Line Tools are sufficient.
    swift build "${BUILD_FLAGS[@]}" --arch arm64
    ARM_BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --arch arm64 --show-bin-path)"
    swift build "${BUILD_FLAGS[@]}" --arch x86_64
    INTEL_BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --arch x86_64 --show-bin-path)"
    BIN_DIR="$ROOT/.build/universal-$CONFIG"
    mkdir -p "$BIN_DIR"
    xcrun lipo -create "$ARM_BIN_DIR/Peekaboo" "$INTEL_BIN_DIR/Peekaboo" -output "$BIN_DIR/Peekaboo"
    xcrun lipo "$BIN_DIR/Peekaboo" -verify_arch arm64 x86_64
else
    swift build "${BUILD_FLAGS[@]}"
    BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"
fi

echo "› Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Peekaboo" "$APP/Contents/MacOS/Peekaboo"
cp "$ROOT/Support/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" -e "s/__BUNDLE_ID__/$BUNDLE_ID/" \
    "$ROOT/Support/Info.plist" > "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :DNUpdatePublicKey $UPDATE_PUBLIC_KEY" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" > /dev/null
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [[ "$CONFIG" == "release" ]]; then
    strip -x "$APP/Contents/MacOS/Peekaboo"
fi

echo "› Signing with: $SIGN_IDENTITY"
# Finder/File Provider may add bundle metadata in synced project folders. These attributes
# invalidate code signing; remove only those attributes from our generated bundle.
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
SIGN_FLAGS=(--force --options runtime)
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    SIGN_FLAGS+=(--timestamp=none)
else
    SIGN_FLAGS+=(--timestamp)
fi
codesign "${SIGN_FLAGS[@]}" --entitlements "$ROOT/Support/Peekaboo.entitlements" --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

echo "✓ Built $APP ($VERSION, build $BUILD_NUMBER)"
