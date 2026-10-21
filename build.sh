#!/bin/zsh
# Builds, signs and installs "Metadata Remover".
#   ./build.sh               build + install to /Applications (or ~/Applications)
#   ./build.sh --no-install  build only, into ./build/
set -euo pipefail

ROOT=${0:A:h}
APP_NAME="Metadata Remover"
EXECUTABLE="MetadataRemover"
OLD_APP_NAMES=("Video Metadata Remover")       # earlier names of this app, removed on install
BUILD="$ROOT/build"
APP="$BUILD/$APP_NAME.app"
INSTALL=1
[[ "${1:-}" == "--no-install" ]] && INSTALL=0

echo "==> Compiling (Swift 6, warnings are errors)"
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -swift-version 6 -parse-as-library -O -warnings-as-errors \
    -target arm64-apple-macos14.0 \
    -o "$APP/Contents/MacOS/$EXECUTABLE" \
    $(find "$ROOT/Sources" -name '*.swift' | sort)

echo "==> Assembling bundle"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
xcrun actool "$ROOT/icon/AppIcon.icon" --compile "$APP/Contents/Resources" \
    --output-partial-info-plist "$BUILD/actool-partial.plist" --app-icon AppIcon --include-all-app-icons \
    --platform macosx --minimum-deployment-target 14.0 --target-device mac >/dev/null
rm -f "$BUILD/actool-partial.plist"

echo "==> Signing (ad-hoc)"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP"

if (( ! INSTALL )); then
    echo "Built: $APP"
    exit 0
fi

DEST_DIR=/Applications
[[ -w "$DEST_DIR" ]] || DEST_DIR="$HOME/Applications"
mkdir -p "$DEST_DIR"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

echo "==> Installing to $DEST_DIR"
osascript -e 'tell application id "local.videometadataremover" to quit' >/dev/null 2>&1 || true
sleep 1
for name in "$APP_NAME" $OLD_APP_NAMES; do
    for dir in /Applications "$HOME/Applications"; do
        if [[ -d "$dir/$name.app" ]]; then
            "$LSREGISTER" -u "$dir/$name.app" >/dev/null 2>&1 || true
            rm -rf "$dir/$name.app"
        fi
    done
done
ditto "$APP" "$DEST_DIR/$APP_NAME.app"
xattr -cr "$DEST_DIR/$APP_NAME.app"
"$LSREGISTER" -f "$DEST_DIR/$APP_NAME.app"
touch "$DEST_DIR/$APP_NAME.app"
echo "Installed: $DEST_DIR/$APP_NAME.app"
