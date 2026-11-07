#!/usr/bin/env bash
# Ad-hoc sign a vRain.app, or Developer ID sign and notarize when secrets exist.
# Secrets (all required for notarization; otherwise this stays ad-hoc):
#   MACOS_CERTIFICATE_P12_BASE64  base64 of a Developer ID Application .p12
#   MACOS_CERTIFICATE_PASSWORD    password for that .p12
#   APPLE_TEAM_ID                 10-character Team ID
#   APPLE_API_KEY_ID              App Store Connect API key id
#   APPLE_API_ISSUER              API issuer UUID
#   APPLE_API_KEY                 base64 of the AuthKey .p8 file
set -eu
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
FLAG=$ROOT/build/single/developer-id-signed

have_secrets() {
  [ -n "${MACOS_CERTIFICATE_P12_BASE64:-}" ] &&
    [ -n "${MACOS_CERTIFICATE_PASSWORD:-}" ] &&
    [ -n "${APPLE_TEAM_ID:-}" ] &&
    [ -n "${APPLE_API_KEY_ID:-}" ] &&
    [ -n "${APPLE_API_ISSUER:-}" ] &&
    [ -n "${APPLE_API_KEY:-}" ]
}

decode_env() {
  dest=$1
  name=$2
  py=python3
  if ! command -v python3 >/dev/null 2>&1; then
    py=python
  fi
  "$py" - "$dest" "$name" << 'PY'
import os, base64, sys
open(sys.argv[1], "wb").write(base64.b64decode(os.environ[sys.argv[2]]))
PY
}

if [ "${1:-}" = "--notarize" ]; then
  dmg=$2
  if [ ! -f "$FLAG" ]; then
    echo "macos: ad-hoc build, notarization skipped"
    exit 0
  fi
  if ! have_secrets; then
    echo "macos: notarization secrets missing" >&2
    exit 1
  fi
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  decode_env "$work/AuthKey.p8" APPLE_API_KEY
  xcrun notarytool submit "$dmg" \
    --key "$work/AuthKey.p8" \
    --key-id "$APPLE_API_KEY_ID" \
    --issuer "$APPLE_API_ISSUER" \
    --wait
  xcrun stapler staple "$dmg"
  echo "macos: notarized $dmg"
  exit 0
fi

APP=$1
[ -d "$APP" ] || { echo "app not found: $APP" >&2; exit 1; }
mkdir -p "$(dirname "$FLAG")"
rm -f "$FLAG"

adhoc() {
  codesign --force --sign - --identifier org.vrain.web "$APP/Contents/MacOS/vRain"
  codesign --force --sign - --identifier org.vrain.web "$APP"
  echo "macos: ad-hoc signature"
}

if ! have_secrets; then
  if [ -n "${MACOS_CERTIFICATE_P12_BASE64:-}${MACOS_CERTIFICATE_PASSWORD:-}${APPLE_TEAM_ID:-}${APPLE_API_KEY_ID:-}${APPLE_API_ISSUER:-}${APPLE_API_KEY:-}" ]; then
    echo "macos: signing secrets are incomplete" >&2
    exit 1
  fi
  adhoc
  exit 0
fi

work=$(mktemp -d)
keychain=$work/vrain.keychain-db
pass=$(openssl rand -hex 24)
cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
decode_env "$work/cert.p12" MACOS_CERTIFICATE_P12_BASE64
security create-keychain -p "$pass" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$pass" "$keychain"
security import "$work/cert.p12" -k "$keychain" -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$pass" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
identity=$(security find-identity -p codesigning -v "$keychain" | awk -F '"' -v team="$APPLE_TEAM_ID" 'index($2, team) { print $2; exit }')
[ -n "$identity" ] || { echo "Developer ID identity not found for team $APPLE_TEAM_ID" >&2; exit 1; }
codesign --force --options runtime --timestamp --sign "$identity" "$APP/Contents/MacOS/vRain"
codesign --force --options runtime --timestamp --sign "$identity" "$APP"
: > "$FLAG"
echo "macos: signed with Developer ID"
