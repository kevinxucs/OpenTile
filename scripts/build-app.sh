#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
swift build --disable-sandbox -debug-info-format none -c release
BIN_DIR="$(swift build --disable-sandbox -debug-info-format none -c release --show-bin-path)"
./scripts/build-icon.sh
for NAME in OpenTile OpenTileFixture; do
  DEST="build/$NAME.app/Contents"
  mkdir -p "$DEST/MacOS" "$DEST/Resources"
  cp "$BIN_DIR/OpenTile" "$DEST/MacOS/OpenTile"
  cp build/OpenTile.icns "$DEST/Resources/OpenTile.icns"
  if [[ "$NAME" == OpenTileFixture ]]; then
    IDENTIFIER=org.opentile.fixture
  else
    IDENTIFIER=org.opentile.app
  fi
  cat > "$DEST/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$IDENTIFIER</string>
<key>CFBundleName</key><string>$NAME</string>
<key>CFBundleDisplayName</key><string>$NAME</string>
<key>CFBundleExecutable</key><string>OpenTile</string>
<key>CFBundleIconFile</key><string>OpenTile</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
  codesign --force --sign - --identifier "$IDENTIFIER" "build/$NAME.app"
done
printf 'Built %s/build/OpenTile.app\n' "$PWD"
