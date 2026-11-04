#!/usr/bin/env bash
# Pack one double-clickable file from a staged vRain-Web directory.
set -eu
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

if [ $# -lt 1 ]; then
  echo "usage: packaging/pack-single.sh <stage-dir>" >&2
  exit 1
fi

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
STAGE=$1
[ -d "$STAGE" ] || { echo "stage not found: $STAGE" >&2; exit 1; }

base=$(basename "$STAGE")
plat=${PLATFORM:-}
if [ -z "$plat" ]; then
  case "$base" in
    vRain-Web-*) plat=${base#vRain-Web-} ;;
    *) echo "cannot detect platform from $base" >&2; exit 1 ;;
  esac
fi

VERSION=${VRAIN_VERSION:-${VERSION:-dev}}
VERSION=$(printf '%s' "$VERSION" | tr -c 'A-Za-z0-9._-' '-')

log() { printf '==> %s\n' "$*"; }

builddir=$ROOT/build/single
rm -rf "$builddir"
mkdir -p "$builddir" "$ROOT/dist"
launcher=$builddir/vrain-launcher
if [ "$plat" = "windows-x64" ]; then
  launcher=$builddir/vrain-launcher.exe
fi

log "build launcher"
(
  cd "$ROOT/packaging/launcher"
  if [ "$plat" = "windows-x64" ]; then
    CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -H windowsgui" -o "$launcher" .
  else
    CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o "$launcher" .
  fi
)

bytes_of() {
  wc -c < "$1" | tr -d '[:space:]'
}

case "$plat" in
  windows-x64)
    out=$ROOT/dist/vRain-${VERSION}-windows-x64.exe
    log "pack $out"
    (cd "$ROOT/packaging/launcher" && go run ./cmd/pack "$launcher" "$STAGE" "$out")
    bash "$ROOT/packaging/sign-windows.sh" "$out"
    log "single-file bytes=$(bytes_of "$out") $out"
    ;;
  linux-*)
    suffix=${plat#linux-}
    out=$ROOT/dist/vRain-${VERSION}-linux-${suffix}
    log "pack $out"
    (cd "$ROOT/packaging/launcher" && go run ./cmd/pack "$launcher" "$STAGE" "$out")
    chmod +x "$out"
    log "single-file bytes=$(bytes_of "$out") $out"
    ;;
  darwin-*)
    chip=arm64
    if [ "$plat" = "darwin-x64" ]; then
      chip=x64
    fi
    payload=$builddir/payload.bin
    log "pack macOS payload"
    (cd "$ROOT/packaging/launcher" && go run ./cmd/pack - "$STAGE" "$payload")
    app=$builddir/vRain.app
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$launcher" "$app/Contents/MacOS/vRain"
    cp "$payload" "$app/Contents/Resources/payload.bin"
    chmod +x "$app/Contents/MacOS/vRain"
    bundle_version=${VERSION#v}
    case "$bundle_version" in
      *[!0-9.]*) bundle_version=1.5.1 ;;
    esac
    sed "s/@@VERSION@@/${bundle_version}/g" "$ROOT/packaging/macos/Info.plist" > "$app/Contents/Info.plist"
    bash "$ROOT/packaging/sign-macos.sh" "$app"
    dmg_root=$builddir/dmg-root
    mkdir -p "$dmg_root"
    cp -R "$app" "$dmg_root/vRain.app"
    dmg=$ROOT/dist/vRain-${VERSION}-macos-${chip}.dmg
    rm -f "$dmg"
    hdiutil create -volname "vRain" -srcfolder "$dmg_root" -ov -format UDZO "$dmg"
    bash "$ROOT/packaging/sign-macos.sh" --notarize "$dmg"
    log "single-file bytes=$(bytes_of "$dmg") $dmg"
    ;;
  *)
    echo "unsupported platform: $plat" >&2
    exit 1
    ;;
esac
