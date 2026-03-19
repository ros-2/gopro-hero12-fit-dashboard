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
    [--font '/path/to/font.ttf' or 'Roboto-Medium.ttf'] \
    [--profile auto|nvgpu|nnvgpu|<profile>] \
    [--encoder auto|cpu|qsv|nvenc] \
    [--cpu-preset ultrafast|superfast|veryfast|faster|fast|medium] \
    [--cpu-crf N] \
    [--ffmpeg-threads N] \
    [--workdir /fast/local/path] \
    [--no-double-buffer] \
    [--no-map] \
    [--keep-temp]

Hero12-focused defaults:
- no basemap tiles (line-only route)
- speed + power, and cadence when present in FIT/GPX
- add --with-hr to include heart rate
- first N seconds clean video, then overlays
- render temp files on Linux disk for WSL speed when output is on /mnt/*
- auto GPU encode for final stitch if available (QSV/NVENC), otherwise libx264
- optional --no-map mode for metric-only overlay (no map panel)
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

has_cadence_data() {
  local telemetry_file="$1"
  local result

  result="$(
    PYTHONPATH="$ROOT_DIR:${PYTHONPATH:-}" "$PYTHON_BIN" -c '
import sys
from pathlib import Path
from gopro_overlay.loading import load_external
from gopro_overlay.units import units

ts = load_external(Path(sys.argv[1]), units)
print("yes" if any(item.cad is not None for item in ts.items()) else "no")
' "$telemetry_file" 2>/dev/null || echo "no"
  )"

  [[ "$result" == "yes" ]]
}

has_ffmpeg_encoder() {
  local encoder="$1"
  ffmpeg -hide_banner -encoders 2>/dev/null | grep -qE "[[:space:]]${encoder}[[:space:]]*$"
}

choose_overlay_profile() {
  if [[ "$PROFILE" != "auto" ]]; then
    echo "$PROFILE"
    return
  fi

  if has_ffmpeg_encoder "h264_nvenc"; then
    echo "nvgpu"
    return
  fi

  echo ""
}

choose_stitch_encoder() {
  if [[ "$ENCODER" != "auto" ]]; then
    echo "$ENCODER"
    return
  fi

  if has_ffmpeg_encoder "h264_qsv"; then
    echo "qsv"
    return
  fi

  if has_ffmpeg_encoder "h264_nvenc"; then
    echo "nvenc"
    return
  fi

  echo "cpu"
}

build_stitch_codec_args() {
  local stitch_encoder="$1"
  case "$stitch_encoder" in
    qsv)
      STITCH_CODEC_ARGS=(
        -c:v h264_qsv
        -global_quality 20
        -look_ahead 0
        -preset medium
        -movflags +faststart
      )
      ;;
    nvenc)
      STITCH_CODEC_ARGS=(
        -c:v h264_nvenc
        -rc:v vbr_hq
        -cq:v 19
        -b:v 0
        -preset p5
        -movflags +faststart
      )
      ;;
    cpu)
      STITCH_CODEC_ARGS=(
        -c:v libx264
        -preset "$CPU_PRESET"
        -crf "$CPU_CRF"
        -threads "$FFMPEG_THREADS"
        -movflags +faststart
      )
      ;;
    *)
      echo "Unsupported --encoder: $stitch_encoder"
      exit 1
      ;;
  esac
}

run_stitch_ffmpeg() {
  local stitch_encoder="$1"
  build_stitch_codec_args "$stitch_encoder"

  ffmpeg -y \
    -i "$VIDEO" \
    -i "$OVERLAY_FULL" \
    -filter_complex "[0:v]trim=0:${INTRO_SECONDS},setpts=PTS-STARTPTS[v0];[0:a]atrim=0:${INTRO_SECONDS},asetpts=PTS-STARTPTS[a0];[1:v]trim=start=${INTRO_SECONDS},setpts=PTS-STARTPTS[v1];[1:a]atrim=start=${INTRO_SECONDS},asetpts=PTS-STARTPTS[a1];[v0][a0][v1][a1]concat=n=2:v=1:a=1[v][a]" \
    -map "[v]" -map "[a]" \
    "${STITCH_CODEC_ARGS[@]}" \
    -c:a aac -b:a 192k \
    "$STITCH_TMP"
}

VIDEO=""
FIT=""
OUTPUT=""
WITH_HR="false"
TOUCH_UTC=""
OFFSET_SECONDS="0"
INTRO_SECONDS="20"
FONT=""
PROFILE="auto"
ENCODER="auto"
CPU_PRESET="fast"
CPU_CRF="17"
WORKDIR=""
KEEP_TEMP="false"
USE_DOUBLE_BUFFER="true"
FFMPEG_THREADS="$(nproc 2>/dev/null || echo 8)"
WORKDIR_CREATED_BY_SCRIPT="false"
NO_MAP="false"

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
    --profile) PROFILE="$2"; shift 2 ;;
    --encoder) ENCODER="$2"; shift 2 ;;
    --cpu-preset) CPU_PRESET="$2"; shift 2 ;;
    --cpu-crf) CPU_CRF="$2"; shift 2 ;;
    --ffmpeg-threads) FFMPEG_THREADS="$2"; shift 2 ;;
    --workdir) WORKDIR="$2"; shift 2 ;;
    --keep-temp) KEEP_TEMP="true"; shift ;;
    --no-double-buffer) USE_DOUBLE_BUFFER="false"; shift ;;
    --no-map) NO_MAP="true"; shift ;;
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

PYTHON_BIN="$ROOT_DIR/.venv/bin/python"
if [[ ! -x "$PYTHON_BIN" ]]; then
  PYTHON_BIN="python3"
fi

if [[ "$NO_MAP" == "true" ]]; then
  LAYOUT="$SCRIPT_DIR/hero12-metrics-only-nohr-4k.xml"
  if has_cadence_data "$FIT"; then
    LAYOUT="$SCRIPT_DIR/hero12-metrics-only-cad-4k.xml"
  fi
  if [[ "$WITH_HR" == "true" && "$(basename "$LAYOUT")" == "hero12-metrics-only-cad-4k.xml" ]]; then
    LAYOUT="$SCRIPT_DIR/hero12-metrics-only-hr-cad-4k.xml"
  elif [[ "$WITH_HR" == "true" ]]; then
    LAYOUT="$SCRIPT_DIR/hero12-metrics-only-hr-4k.xml"
  fi
else
  LAYOUT="$SCRIPT_DIR/hero12-line-only-nohr-4k.xml"
  if has_cadence_data "$FIT"; then
    LAYOUT="$SCRIPT_DIR/hero12-line-only-cad-4k.xml"
  fi
  if [[ "$WITH_HR" == "true" && "$(basename "$LAYOUT")" == "hero12-line-only-cad-4k.xml" ]]; then
    LAYOUT="$SCRIPT_DIR/hero12-line-only-hr-cad-4k.xml"
  elif [[ "$WITH_HR" == "true" ]]; then
    LAYOUT="$SCRIPT_DIR/hero12-line-only-hr-4k.xml"
  fi
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
OUTPUT_BASENAME="$(basename "${OUTPUT%.*}")"

if [[ -z "$WORKDIR" ]]; then
  if [[ "$OUTPUT" == /mnt/* ]]; then
    WORKDIR="$(mktemp -d /tmp/gopro-render-XXXXXX)"
  else
    WORKDIR="$(mktemp -d "$(dirname "$OUTPUT")/gopro-render-XXXXXX")"
  fi
  WORKDIR_CREATED_BY_SCRIPT="true"
else
  mkdir -p "$WORKDIR"
fi

OVERLAY_FULL="$WORKDIR/${OUTPUT_BASENAME}-overlay-full.mp4"
STITCH_TMP="$WORKDIR/${OUTPUT_BASENAME}-stitched.mp4"

cleanup() {
  if [[ "$KEEP_TEMP" == "true" ]]; then
    return
  fi
  if [[ "$WORKDIR_CREATED_BY_SCRIPT" == "true" && -d "$WORKDIR" ]]; then
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

SELECTED_FONT="$(choose_font)"
OVERLAY_PROFILE="$(choose_overlay_profile)"
STITCH_ENCODER="$(choose_stitch_encoder)"

echo "Using font: $SELECTED_FONT"
echo "Using layout: $(basename "$LAYOUT")"
echo "Render workdir: $WORKDIR"
if [[ -n "$OVERLAY_PROFILE" ]]; then
  echo "Overlay ffmpeg profile: $OVERLAY_PROFILE"
else
  echo "Overlay ffmpeg profile: default"
fi
echo "Final stitch encoder: $STITCH_ENCODER"

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

if [[ "$USE_DOUBLE_BUFFER" == "true" ]]; then
  ARGS=(--double-buffer "${ARGS[@]}")
fi

if [[ -n "$OVERLAY_PROFILE" ]]; then
  ARGS=(--profile "$OVERLAY_PROFILE" "${ARGS[@]}")
fi

PYTHONPATH="$ROOT_DIR:${PYTHONPATH:-}" "$PYTHON_BIN" "$ROOT_DIR/bin/gopro-dashboard.py" "${ARGS[@]}"

if ! run_stitch_ffmpeg "$STITCH_ENCODER"; then
  if [[ "$STITCH_ENCODER" != "cpu" ]]; then
    echo "Falling back to CPU encoder (libx264)."
    run_stitch_ffmpeg "cpu"
  else
    exit 1
  fi
fi

mv -f "$STITCH_TMP" "$OUTPUT"

echo "Done: $OUTPUT"
