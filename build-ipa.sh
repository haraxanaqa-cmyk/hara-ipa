#!/usr/bin/env bash
#
# Builds DylibLens.ipa. Run on macOS with Xcode command line tools installed.
#
#   ./build-ipa.sh                 -> unsigned .ipa in dist/ (sign it later with Esign/Sideloadly)
#   TEAM_ID=ABCDE12345 ./build-ipa.sh   -> also exports a signed .ipa via exportOptions.plist
#
set -euo pipefail
cd "$(dirname "$0")"

SCHEME="DylibLens"
PROJECT="DylibLens.xcodeproj"
BUILD_DIR="build"
OUT_DIR="dist"
IPA_NAME="DylibLens.ipa"

log() { printf '\033[36m==>\033[0m %s\n' "$*"; }

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode (App Store) and run: sudo xcode-select --switch /Applications/Xcode.app"
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  log "xcodegen not found, fetching it"
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    TMP="$(mktemp -d)"
    curl -sSL -o "$TMP/xcodegen.zip" https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip
    unzip -q "$TMP/xcodegen.zip" -d "$TMP"
    export PATH="$TMP/xcodegen/bin:$PATH"
  fi
fi

log "Generating $PROJECT"
xcodegen generate --spec project.yml

rm -rf "$BUILD_DIR" "$OUT_DIR"
mkdir -p "$OUT_DIR"

if [ -n "${TEAM_ID:-}" ]; then
  log "Building signed (team $TEAM_ID)"
  cat > /tmp/DylibLens-export.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>development</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>stripSwiftSymbols</key><true/>
  <key>compileBitcode</key><false/>
</dict></plist>
PLIST
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -sdk iphoneos -derivedDataPath "$BUILD_DIR" \
    -archivePath "$OUT_DIR/DylibLens.xcarchive" \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic \
    archive
  xcodebuild -exportArchive -archivePath "$OUT_DIR/DylibLens.xcarchive" \
    -exportPath "$OUT_DIR/export" -exportOptionsPlist /tmp/DylibLens-export.plist
  cp "$OUT_DIR/export/DylibLens.ipa" "$OUT_DIR/$IPA_NAME"
else
  log "Building unsigned (device build, no code signature)"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -sdk iphoneos -derivedDataPath "$BUILD_DIR" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    build
  APP="$BUILD_DIR/Build/Products/Release-iphoneos/DylibLens.app"
  [ -d "$APP" ] || { echo "Build produced no .app at $APP"; exit 1; }
  rm -rf "$OUT_DIR/Payload"
  mkdir -p "$OUT_DIR/Payload"
  cp -R "$APP" "$OUT_DIR/Payload/"
  ( cd "$OUT_DIR" && zip -qry "$IPA_NAME" Payload )
  rm -rf "$OUT_DIR/Payload"
fi

log "Done: $OUT_DIR/$IPA_NAME"
ls -lh "$OUT_DIR/$IPA_NAME"
