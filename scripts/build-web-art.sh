#!/usr/bin/env bash
# Converts the artwork delivered by the art team (web/art/*.jpg|png) into the
# transparent assets the site serves (apps/web/img/illustrations/*.png).
#
# The delivered files are line art on a white background. The conversion derives
# the alpha channel from the luminance, so the paper disappears while the
# anti-aliased edges of the strokes are preserved, and then quantises the result
# to a small palette: without it the RGBA files are ~650 KB each.
#
# Install the toolchain with `brew install imagemagick` and run `npm run web:art`.
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="web/art"
OUT="apps/web/img/illustrations"

command -v magick >/dev/null || { echo "error: ImageMagick (magick) is required" >&2; exit 1; }
[ -d "$SRC" ] || { echo "error: missing source directory $SRC" >&2; exit 1; }

mkdir -p "$OUT"
count=0

for source in "$SRC"/*.jpg "$SRC"/*.jpeg "$SRC"/*.png; do
  [ -e "$source" ] || continue
  name="$(basename "$source")"
  name="${name%.*}"

  magick "$source" \
    -fuzz 4% -trim +repage \
    \( +clone -colorspace gray -negate -level 0%,60% \) \
    -alpha off -compose copy_opacity -composite \
    -resize '1100x1100>' \
    -strip +dither -colors 32 -define png:compression-level=9 \
    "$OUT/$name.png"

  count=$((count + 1))
  printf '  %-16s %s\n' "$name" "$(magick identify -format '%wx%h %b' "$OUT/$name.png")"
done

# The old vector placeholders are gone for every name that now ships as art.
for source in "$SRC"/*.jpg "$SRC"/*.jpeg "$SRC"/*.png; do
  [ -e "$source" ] || continue
  name="$(basename "$source")"
  rm -f "$OUT/${name%.*}.svg"
done

echo "Converted $count delivered illustrations into $OUT."
