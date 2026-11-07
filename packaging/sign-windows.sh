#!/usr/bin/env bash
# Authenticode-sign a vRain exe when both secrets are set.
# The signature is applied after the payload is appended. signtool writes the
# certificate after that overlay, and the launcher finds its footer by magic.
# Secrets:
#   WINDOWS_CERTIFICATE_PFX_BASE64  base64 of the Authenticode .pfx
#   WINDOWS_CERTIFICATE_PASSWORD    password for that .pfx
set -eu
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

exe=$1
[ -f "$exe" ] || { echo "exe not found: $exe" >&2; exit 1; }

if [ -z "${WINDOWS_CERTIFICATE_PFX_BASE64:-}" ] && [ -z "${WINDOWS_CERTIFICATE_PASSWORD:-}" ]; then
  echo "windows: no Authenticode certificate, leaving the exe unsigned"
  exit 0
fi
if [ -z "${WINDOWS_CERTIFICATE_PFX_BASE64:-}" ] || [ -z "${WINDOWS_CERTIFICATE_PASSWORD:-}" ]; then
  echo "windows: signing secrets are incomplete" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
py=python
if ! command -v python >/dev/null 2>&1; then
  py=python3
fi
"$py" - "$work/cert.pfx" << 'PY'
import os, base64, sys
open(sys.argv[1], "wb").write(base64.b64decode(os.environ["WINDOWS_CERTIFICATE_PFX_BASE64"]))
PY

signtool=""
if command -v signtool.exe >/dev/null 2>&1; then
  signtool=$(command -v signtool.exe)
elif [ -d "/c/Program Files (x86)/Windows Kits/10/bin" ]; then
  signtool=$(find "/c/Program Files (x86)/Windows Kits/10/bin" -name signtool.exe -path '*/x64/*' | sort | tail -n 1)
fi
[ -n "$signtool" ] || { echo "signtool.exe not found" >&2; exit 1; }

win_exe=$exe
win_pfx=$work/cert.pfx
if command -v cygpath >/dev/null 2>&1; then
  win_exe=$(cygpath -w "$exe")
  win_pfx=$(cygpath -w "$work/cert.pfx")
fi
MSYS_NO_PATHCONV=1 "$signtool" sign //fd SHA256 //f "$win_pfx" //p "$WINDOWS_CERTIFICATE_PASSWORD" //tr http://timestamp.digicert.com //td SHA256 "$win_exe"
echo "windows: signed $exe"
