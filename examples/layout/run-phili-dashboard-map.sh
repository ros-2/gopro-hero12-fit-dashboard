#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash examples/layout/run-phili-dashboard-map.sh
#   bash examples/layout/run-phili-dashboard-map.sh --with-hr
#
# This script uses map-on HUD mode:
# - line-only route + blue dot
# - no map frame/panel background
# - tuned sync + intro timing
# - Montserrat Bold font for metrics

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

VIDEO="/mnt/c/Users/phili/Downloads/GX010405_1712867428148.mp4"
FIT="/mnt/c/Users/phili/Downloads/Dusk.fit"
OUTPUT="/mnt/c/Users/phili/Downloads/GX010405_1712867428148-dashboard-map-v1.mp4"

# Keep visual start; hold telemetry briefly then run slightly later
TOUCH_UTC="2024-04-11 19:35:03.500 UTC"
INTRO_SECONDS="25.5"
FONT=""

for candidate in \
  "/usr/share/fonts/truetype/montserrat/Montserrat-Bold.ttf" \
  "/usr/share/fonts/opentype/montserrat/Montserrat-Bold.ttf" \
  "/mnt/c/Windows/Fonts/Montserrat-Bold.ttf" \
  "/mnt/c/Windows/Fonts/Montserrat Bold.ttf" \
  "/mnt/c/Users/phili/AppData/Local/Microsoft/Windows/Fonts/Montserrat-Bold.ttf" \
  "/mnt/c/Users/phili/AppData/Local/Microsoft/Windows/Fonts/Montserrat Bold.ttf"
do
  if [[ -f "$candidate" ]]; then
    FONT="$candidate"
    break
  fi
done

if [[ -z "$FONT" ]]; then
  echo "Montserrat Bold font not found."
  echo "Install Montserrat Bold in Windows/Ubuntu, or edit FONT path in:"
  echo "  examples/layout/run-phili-dashboard-map.sh"
  exit 1
fi

cd "$ROOT_DIR"

bash examples/layout/render-modern-descent.sh \
  --video "$VIDEO" \
  --fit "$FIT" \
  --output "$OUTPUT" \
  --touch-utc "$TOUCH_UTC" \
  --intro-seconds "$INTRO_SECONDS" \
  --font "$FONT" \
  --encoder qsv \
  "$@"
