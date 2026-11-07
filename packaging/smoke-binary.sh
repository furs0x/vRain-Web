#!/usr/bin/env bash
# Launch one single-file build, time startup and a one-page sample.
set -eu
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

if [ $# -lt 1 ] || [ ! -f "$1" ]; then
  echo "usage: packaging/smoke-binary.sh <binary-or-dmg>" >&2
  exit 1
fi
BIN=$1

now_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(int(time.time()*1000))'
  elif command -v python >/dev/null 2>&1; then
    python -c 'import time; print(int(time.time()*1000))'
  else
    echo "$(( $(date +%s) * 1000 ))"
  fi
}

WORKDIR=$(mktemp -d)
if command -v cygpath >/dev/null 2>&1; then
  CACHE=$(cygpath -m "$WORKDIR/cache")
else
  CACHE=$WORKDIR/cache
fi
mkdir -p "$CACHE"
MOUNT=""
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    if command -v taskkill >/dev/null 2>&1; then
      taskkill //F //T //PID "$SERVER_PID" >/dev/null 2>&1 || true
    else
      kill "$SERVER_PID" >/dev/null 2>&1 || true
      sleep 0.2
      kill -9 "$SERVER_PID" >/dev/null 2>&1 || true
    fi
  fi
  if [ -n "$MOUNT" ]; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || hdiutil detach -force "$MOUNT" >/dev/null 2>&1 || true
  fi
  if [ "${KEEP:-}" != "1" ]; then
    rm -rf "$WORKDIR"
  else
    echo "kept $WORKDIR"
  fi
}
trap cleanup EXIT

RUN=$BIN
case "$BIN" in
  *.dmg)
    MOUNT=$WORKDIR/mnt
    mkdir -p "$MOUNT"
    hdiutil attach "$BIN" -nobrowse -mountpoint "$MOUNT"
    RUN=$(find "$MOUNT" -name vRain -path '*/Contents/MacOS/vRain' | head -n 1 || true)
    [ -n "$RUN" ] || { echo "vRain.app missing in dmg" >&2; exit 1; }
    ;;
  *)
    chmod +x "$RUN" 2>/dev/null || true
    ;;
esac

wait_ready() {
  log=$1
  start=$(now_ms)
  i=0
  url=""
  while [ "$i" -lt 200 ]; do
    if [ -f "$log" ] && grep -q VRAIN_READY "$log"; then
      url=$(grep VRAIN_READY "$log" | awk '{print $2; exit}')
      url=$(printf '%s' "$url" | tr -d '\r')
      break
    fi
    i=$((i + 1))
    sleep 0.5
  done
  end=$(now_ms)
  if [ -z "$url" ]; then
    echo "single-file server failed to start" >&2
    cat "$log" >&2 || true
    exit 1
  fi
  printf '%s %s\n' "$url" "$((end - start))"
}

stop_server() {
  if [ -z "$SERVER_PID" ]; then
    return 0
  fi
  if command -v taskkill >/dev/null 2>&1; then
    taskkill //F //T //PID "$SERVER_PID" >/dev/null 2>&1 || true
  else
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    sleep 0.3
    kill -9 "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  wait "$SERVER_PID" >/dev/null 2>&1 || true
  SERVER_PID=""
}

launch() {
  log=$1
  : > "$log"
  VRAIN_NO_BROWSER=1 VRAIN_CACHE_DIR="$CACHE" "$RUN" >"$log" 2>&1 &
  SERVER_PID=$!
}

echo "binary $(wc -c < "$BIN" | tr -d '[:space:]') bytes $BIN"
launch "$WORKDIR/cold.log"
cold=$(wait_ready "$WORKDIR/cold.log")
URL=$(printf '%s' "$cold" | awk '{print $1}')
COLD_MS=$(printf '%s' "$cold" | awk '{print $2}')
echo "cold_start_ms=$COLD_MS"
curl -fsS "${URL}api/health"
echo

gen_start=$(now_ms)
resp=$(curl -fsS -X POST "${URL}api/jobs" -H 'Content-Type: application/json' \
  -d '{"book":"sample","from":1,"to":1,"testPages":1,"compress":true}')
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
    echo "$st" >&2
    exit 1
  fi
  i=$((i + 1))
  sleep 0.5
done
[ "$ok" = 1 ] || { echo "generation timed out" >&2; exit 1; }
gen_end=$(now_ms)
echo "generate_ms=$((gen_end - gen_start))"
pdf=$(find "$WORKDIR/cache" -type f -name '*.pdf' -path '*/books/sample/*' | head -n 1 || true)
[ -n "$pdf" ] || { echo "sample pdf missing" >&2; exit 1; }
case "$pdf" in
  *已压缩*) ;;
  *) echo "expected a compressed pdf, got $pdf" >&2; exit 1 ;;
esac
head -c 4 "$pdf" | od -An -tx1 | grep -q '25 50 44 46'
echo "pdf ok $pdf"

stop_server
i=0
while [ "$i" -lt 40 ]; do
  if ! curl -fsS --max-time 1 "${URL}api/health" >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 0.25
done

launch "$WORKDIR/warm.log"
warm=$(wait_ready "$WORKDIR/warm.log")
WARM_MS=$(printf '%s' "$warm" | awk '{print $2}')
echo "warm_start_ms=$WARM_MS"
curl -fsS "$(printf '%s' "$warm" | awk '{print $1}')api/health" >/dev/null
echo "single-file smoke ok"
