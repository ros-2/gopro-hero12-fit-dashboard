#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  bash examples/layout/render-modern-descent.sh \
    --video /path/to/video.mp4 \
    --fit /path/to/ride.fit_or_ride.gpx \
    --output /path/to/final.mp4 \
    [--with-hr] \
    [--touch-utc 'YYYY-MM-DD HH:MM:SS UTC'] \
    [--offset-seconds N] \
    [--intro-seconds 20] \
    [--font '/path/to/font.ttf' or 'Roboto-Medium.ttf']

Hero12-focused defaults:
- no basemap tiles (line-only route)
- speed + power only (add --with-hr to include heart rate)
- first N seconds clean video, then overlays
USAGE
}

choose_font() {
  if [[ -n "$FONT" ]]; then
    echo "$FONT"
    return
  fi

  if command -v fc-list >/dev/null 2>&1; then
    local selected
    selected="$(fc-list | grep -iE '/Inter-.*(Medium|Regular)\\.(ttf|otf)$' | head -n 1 | cut -d: -f1 || true)"
    if [[ -n "$selected" ]]; then
      echo "$selected"
      return
    fi
  fi

  echo "Roboto-Medium.ttf"
}

VIDEO=""
FIT=""
OUTPUT=""
WITH_HR="false"
TOUCH_UTC=""
OFFSET_SECONDS="0"
INTRO_SECONDS="20"
FONT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --video) VIDEO="$2"; shift 2 ;;
    --fit) FIT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --with-hr) WITH_HR="true"; shift ;;
    --touch-utc) TOUCH_UTC="$2"; shift 2 ;;
    --offset-seconds) OFFSET_SECONDS="$2"; shift 2 ;;
    --intro-seconds) INTRO_SECONDS="$2"; shift 2 ;;
    --font) FONT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$VIDEO" || -z "$FIT" || -z "$OUTPUT" ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

LAYOUT="$SCRIPT_DIR/hero12-line-only-nohr-4k.xml"
if [[ "$WITH_HR" == "true" ]]; then
  LAYOUT="$SCRIPT_DIR/hero12-line-only-hr-4k.xml"
fi

for f in "$VIDEO" "$FIT" "$LAYOUT"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing file: $f"
    exit 1
  fi
done

if [[ -n "$TOUCH_UTC" ]]; then
  touch -d "$TOUCH_UTC" "$VIDEO"
fi

if [[ "$OFFSET_SECONDS" != "0" ]]; then
  if ! [[ "$OFFSET_SECONDS" =~ ^-?[0-9]+$ ]]; then
    echo "--offset-seconds must be an integer (e.g. -2, 0, +2)"
    exit 1
  fi
  current_epoch="$(stat -c %Y "$VIDEO")"
  new_epoch="$((current_epoch + OFFSET_SECONDS))"
  touch -d "@$new_epoch" "$VIDEO"
fi

mkdir -p "$(dirname "$OUTPUT")"
OVERLAY_FULL="${OUTPUT%.*}-overlay-full.mp4"

PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
if [[ ! -x "$PYTHON_BIN" ]]; then
  PYTHON_BIN="python3"
fi

SELECTED_FONT="$(choose_font)"
echo "Using font: $SELECTED_FONT"
echo "Using layout: $(basename "$LAYOUT")"

ARGS=(
  --use-fit-only
  --fit "$FIT"
  --video-time-start file-modified
  --layout xml
  --layout-xml "$LAYOUT"
  --font "$SELECTED_FONT"
  "$VIDEO"
  "$OVERLAY_FULL"
)

PYTHONPATH="$ROOT_DIR:${PYTHONPATH:-}" "$PYTHON_BIN" "$ROOT_DIR/bin/gopro-dashboard.py" "${ARGS[@]}"

ffmpeg -y \
  -i "$VIDEO" \
  -i "$OVERLAY_FULL" \
  -filter_complex "[0:v]trim=0:${INTRO_SECONDS},setpts=PTS-STARTPTS[v0];[0:a]atrim=0:${INTRO_SECONDS},asetpts=PTS-STARTPTS[a0];[1:v]trim=start=${INTRO_SECONDS},setpts=PTS-STARTPTS[v1];[1:a]atrim=start=${INTRO_SECONDS},asetpts=PTS-STARTPTS[a1];[v0][a0][v1][a1]concat=n=2:v=1:a=1[v][a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset slow -crf 15 -movflags +faststart \
  -c:a aac -b:a 192k \
  "$OUTPUT"

echo "Done: $OUTPUT"
