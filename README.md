# GoPro Hero12 FIT Dashboard (Focused Workflow)

This repo is configured for one job: render a synced Hero12 overlay from a video plus FIT/GPX telemetry.

## What You Get

The final overlay is designed for riding footage:
- moving route map (line-only, no basemap)
- speed (kph)
- power (watts)
- cadence (rpm), automatically included when cadence exists in the telemetry file
- optional heart rate (BPM)

Render behavior:
- first `N` seconds are clean video (no overlay)
- overlay appears after intro section
- final output is `*.mp4`

## Requirements (WSL / Ubuntu)

```bash
sudo apt update
sudo apt install -y ffmpeg python3 python3-venv fonts-inter fonts-roboto
```

## Setup

From repo root:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Quick Start (Interactive)

```bash
bash examples/layout/run-modern-descent-interactive.sh
```

It asks for:
- video path (`.mp4`)
- telemetry path (`.fit` or `.gpx`)
- output file path
- whether to include HR
- optional sync timestamp and offset
- intro length

## One-Command Render

```bash
bash examples/layout/render-modern-descent.sh \
  --video "/path/to/video.mp4" \
  --fit "/path/to/telemetry.fit" \
  --output "/path/to/output-dashboard.mp4" \
  --touch-utc "2024-04-11 19:35:07 UTC" \
  --offset-seconds 0 \
  --intro-seconds 20
```

Add HR layout:

```bash
bash examples/layout/render-modern-descent.sh \
  --video "/path/to/video.mp4" \
  --fit "/path/to/telemetry.fit" \
  --output "/path/to/output-dashboard.mp4" \
  --with-hr
```

## Cadence Logic

Cadence is automatic:
- if telemetry contains cadence, cadence is shown in the overlay
- if telemetry has no cadence, cadence is omitted

No extra flag is needed.

## Output Files

Given `--output /path/final.mp4`, the workflow creates:
- `/path/final-overlay-full.mp4` (full overlay render)
- `/path/final.mp4` (final stitched result)

## Sync Tuning

Adjust only `--offset-seconds` and rerun:
- movement appears too late: use `+1`, `+2`
- movement appears too early: use `-1`, `-2`

## Notes

- The render script uses local project code (`bin/gopro-dashboard.py`) so your repo edits apply immediately.
- If `.venv/bin/python` exists, it is used automatically; otherwise it falls back to `python3`.
