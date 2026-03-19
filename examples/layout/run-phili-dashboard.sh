#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash examples/layout/run-phili-dashboard.sh
#   bash examples/layout/run-phili-dashboard.sh --with-hr
#   bash examples/layout/run-phili-dashboard.sh --no-map
#
# This script uses your requested settings:
# - tuned sync + intro timing
# - map disabled
# - Montserrat Bold font for metrics

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

VIDEO="/mnt/c/Users/phili/Downloads/GX010405_1712867428148.mp4"
FIT="/mnt/c/Users/phili/Downloads/Dusk.fit"
OUTPUT="/mnt/c/Users/phili/Downloads/GX010405_1712867428148-dashboard-v2.mp4"

# Timing mode:
# - keep visual telemetry start at same place in video
# - hold that initial telemetry for ~1.5s
# - then run the rest ~1.5s later
#
# Achieved by:
# - starting overlay 1.5s earlier
# - shifting telemetry timeline 1.5s later
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
  echo "Install Montserrat Bold in Windows, or edit FONT path in:"
  echo "  examples/layout/run-phili-dashboard.sh"
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
  --no-map \
  "$@"
