# GoPro Hero 12 Dashboard (FIT/GPX Synced)

This local workflow is specifically for **GoPro Hero 12** videos that need telemetry synced from **FIT** (or GPX) files.

What it renders:
- moving route map (line-only, no basemap tiles)
- speed (kph)
- power (watts)
- cadence (rpm) when present in FIT/GPX
- optional heart rate (BPM)

What it always does:
- sync via video file timestamp + offset seconds
- keep first N seconds clean (no overlay), then apply dashboard

## Install fonts (optional but recommended)

```bash
sudo apt update
sudo apt install -y fonts-inter fonts-roboto
```

## Easiest start (interactive)

```bash
bash examples/layout/run-modern-descent-interactive.sh
```

It prompts for:
- video path (`.mp4`)
- telemetry path (`.fit` or `.gpx`)
- output path
- include heart rate or not
- cadence is auto-included when present
- sync time + offset
- intro seconds
- optional font

## Non-interactive command

```bash
bash examples/layout/render-modern-descent.sh \
  --video "/mnt/c/Users/phili/Downloads/GX010405_1712867428148.mp4" \
  --fit "/mnt/c/Users/phili/Downloads/Dusk.fit" \
  --output "/mnt/c/Users/phili/Downloads/gx010405-hero12-dashboard.mp4" \
  --touch-utc "2024-04-11 19:35:07 UTC" \
  --offset-seconds 0 \
  --intro-seconds 20
```

Add heart rate:

```bash
bash examples/layout/render-modern-descent.sh \
  --video "/path/to/video.mp4" \
  --fit "/path/to/file.fit" \
  --output "/path/to/output.mp4" \
  --with-hr
```

## Timing tuning

Adjust only `--offset-seconds` and rerun:
- later overlay movement: `+1`, `+2`
- earlier overlay movement: `-1`, `-2`
