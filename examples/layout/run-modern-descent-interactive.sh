#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RENDER_SCRIPT="$SCRIPT_DIR/render-modern-descent.sh"

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  echo "$s"
}

normalize_path() {
  local p
  p="$(trim "$1")"

  p="${p%\"}"
  p="${p#\"}"
  p="${p%\'}"
  p="${p#\'}"

  if [[ "$p" =~ ^[A-Za-z]: ]]; then
    if command -v wslpath >/dev/null 2>&1; then
      p="$(wslpath -u "$p")"
    fi
  else
    p="${p//\\//}"
  fi

  echo "$p"
}

prompt_file() {
  local prompt="$1"
  local allow_regex="$2"
  local value

  while true; do
    read -r -p "$prompt" value
    value="$(normalize_path "$value")"

    if [[ -z "$value" ]]; then
      echo "Path is required." >&2
      continue
    fi

    if [[ ! -f "$value" ]]; then
      echo "File not found: $value" >&2
      continue
    fi

    if [[ ! "$value" =~ $allow_regex ]]; then
      echo "Unexpected file type: $value" >&2
      continue
    fi

    echo "$value"
    return
  done
}

prompt_int() {
  local prompt="$1"
  local default="$2"
  local value

  while true; do
    read -r -p "$prompt" value
    value="$(trim "$value")"
    if [[ -z "$value" ]]; then
      echo "$default"
      return
    fi
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
      echo "$value"
      return
    fi
    echo "Please enter an integer." >&2
  done
}

echo
echo "Hero12 Dashboard Setup (Interactive)"
echo "-------------------------------------"
echo "Cadence is auto-included when present in FIT/GPX."
echo

VIDEO_PATH="$(prompt_file 'Video file path (.mp4): ' '\.[mM][pP]4$')"
FIT_PATH="$(prompt_file 'Telemetry file path (.fit or .gpx): ' '\.([fF][iI][tT]|[gG][pP][xX])$')"

DEFAULT_OUTPUT_DIR="$(dirname "$VIDEO_PATH")"
VIDEO_BASE="$(basename "$VIDEO_PATH")"
VIDEO_BASE="${VIDEO_BASE%.*}"
DEFAULT_OUTPUT="$DEFAULT_OUTPUT_DIR/${VIDEO_BASE}-hero12-dashboard.mp4"

read -r -p "Output file path [default: $DEFAULT_OUTPUT]: " OUTPUT_PATH_RAW
if [[ -z "$(trim "$OUTPUT_PATH_RAW")" ]]; then
  OUTPUT_PATH="$DEFAULT_OUTPUT"
else
  OUTPUT_PATH="$(normalize_path "$OUTPUT_PATH_RAW")"
fi

if [[ ! "$OUTPUT_PATH" =~ \.[mM][pP]4$ ]]; then
  OUTPUT_PATH="$OUTPUT_PATH.mp4"
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"

read -r -p "Include heart rate if available? [y/N]: " WITH_HR_RAW
WITH_HR_RAW="$(trim "$WITH_HR_RAW")"
WITH_HR_FLAG=""
if [[ "$WITH_HR_RAW" =~ ^[Yy]$ ]]; then
  WITH_HR_FLAG="--with-hr"
fi

read -r -p "Sync base UTC time (optional, e.g. 2024-04-11 19:35:07 UTC): " TOUCH_UTC
TOUCH_UTC="$(trim "$TOUCH_UTC")"

OFFSET_SECONDS="$(prompt_int 'Offset seconds for fine sync [0]: ' '0')"
INTRO_SECONDS="$(prompt_int 'Intro seconds without overlay [20]: ' '20')"

read -r -p "Font path or name (optional, blank = auto Inter/Roboto): " FONT_RAW
FONT="$(normalize_path "$FONT_RAW")"
FONT="$(trim "$FONT")"

CMD=(
  bash "$RENDER_SCRIPT"
  --video "$VIDEO_PATH"
  --fit "$FIT_PATH"
  --output "$OUTPUT_PATH"
  --offset-seconds "$OFFSET_SECONDS"
  --intro-seconds "$INTRO_SECONDS"
)

if [[ -n "$WITH_HR_FLAG" ]]; then
  CMD+=("$WITH_HR_FLAG")
fi

if [[ -n "$TOUCH_UTC" ]]; then
  CMD+=(--touch-utc "$TOUCH_UTC")
fi

if [[ -n "$FONT" ]]; then
  CMD+=(--font "$FONT")
fi

echo
echo "About to run:"
printf '  %q' "${CMD[@]}"
echo
echo

read -r -p "Run now? [Y/n]: " RUN_NOW
RUN_NOW="$(trim "$RUN_NOW")"
if [[ -z "$RUN_NOW" || "$RUN_NOW" =~ ^[Yy]$ ]]; then
  cd "$ROOT_DIR"
  "${CMD[@]}"
else
  echo "Cancelled."
fi
