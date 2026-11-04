#!/usr/bin/env bash
# Start a built package from a clean directory and generate the sample book.
set -eu
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

if [ $# -lt 1 ]; then
  echo "usage: packaging/smoke.sh <archive-or-directory>" >&2
  exit 1
fi
SRC=$1
[ -e "$SRC" ] || { echo "not found: $SRC" >&2; exit 1; }

WORKDIR=$(mktemp -d)
SERVER_PID=""
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    if command -v taskkill >/dev/null 2>&1; then
      taskkill //F //T //PID "$SERVER_PID" >/dev/null 2>&1 || true
    fi
  fi
  if [ "${KEEP:-}" != "1" ]; then
    rm -rf "$WORKDIR"
  else
    echo "kept $WORKDIR"
  fi
}
trap cleanup EXIT

if [ -d "$SRC" ]; then
  cp -a "$SRC" "$WORKDIR/app"
  APP="$WORKDIR/app"
else
  mkdir -p "$WORKDIR/extract"
  case "$SRC" in
    *.zip) tar -xf "$SRC" -C "$WORKDIR/extract" ;;
    *.tar.gz|*.tgz) tar -xzf "$SRC" -C "$WORKDIR/extract" ;;
    *) echo "unknown archive: $SRC" >&2; exit 1 ;;
  esac
  APP=$(find "$WORKDIR/extract" -mindepth 1 -maxdepth 1 -type d | head -1)
fi
[ -n "${APP:-}" ] && [ -d "$APP" ] || { echo "package directory missing" >&2; exit 1; }
cd "$APP"
echo "smoke root: $APP"

LOG="$WORKDIR/server.log"
if [ -x ./runtime/perl/bin/perl ] || [ -f ./start.sh ]; then
  VRAIN_NO_BROWSER=1 ./start.sh >"$LOG" 2>&1 &
  SERVER_PID=$!
elif [ -f ./START.bat ]; then
  VRAIN_NO_BROWSER=1 VRAIN_NO_PAUSE=1 cmd //c START.bat >"$LOG" 2>&1 &
  SERVER_PID=$!
else
  echo "no launcher in package" >&2
  exit 1
fi

URL=""
i=0
while [ "$i" -lt 60 ]; do
  if [ -f "$LOG" ] && grep -q VRAIN_READY "$LOG"; then
    URL=$(grep VRAIN_READY "$LOG" | awk '{print $2; exit}')
    break
  fi
  i=$((i + 1))
  sleep 0.5
done
if [ -z "$URL" ]; then
  echo "server failed to start" >&2
  cat "$LOG" >&2 || true
  exit 1
fi
echo "ready $URL"
curl -fsS "${URL}api/health"
echo

if [ -x ./vrain ]; then
  ./vrain -h >/dev/null
fi
if [ -f ./vrain.bat ]; then
  cmd //c vrain.bat -h >/dev/null
fi

resp=$(curl -fsS -X POST "${URL}api/jobs" -H 'Content-Type: application/json' \
  -d '{"book":"sample","from":1,"to":1,"testPages":1}')
echo "$resp"
job=$(printf '%s' "$resp" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$job" ] || { echo "no job id" >&2; exit 1; }

ok=0
i=0
while [ "$i" -lt 240 ]; do
  st=$(curl -fsS "${URL}api/jobs/${job}")
  if printf '%s' "$st" | grep -q '"status":"done"'; then
    ok=1
    break
  fi
  if printf '%s' "$st" | grep -q '"status":"error"'; then
    echo "generation failed" >&2
    printf '%s\n' "$st" | tail -c 5000 >&2
    exit 1
  fi
  if [ $((i % 15)) -eq 0 ]; then
    echo "waiting ($i)"
  fi
  i=$((i + 1))
  sleep 2
done
[ "$ok" = "1" ] || { echo "timed out" >&2; printf '%s\n' "$st" | tail -c 5000 >&2; exit 1; }

pdf=$(find books/sample -name '*.pdf' -type f | head -1)
[ -n "$pdf" ] || { echo "pdf missing" >&2; exit 1; }
sig=$(./perl -e 'open my $f, "<:raw", shift or die $!; read $f, my $b, 4; print unpack("H*", $b);' "$pdf")
case "$sig" in
  25504446*) echo "pdf ok $pdf" ;;
  *) echo "bad pdf signature: $sig" >&2; exit 1 ;;
esac
echo "smoke ok"
