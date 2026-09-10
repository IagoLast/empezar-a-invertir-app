#!/usr/bin/env bash
# Regenerates the binary assets under apps/web/img from the iOS app artwork and
# the generated Open Graph sources. Run it after changing the app icon, the
# screenshots or the Open Graph cards. The results are committed, so builds and
# CI never need ImageMagick or rsvg-convert.
set -euo pipefail

cd "$(dirname "$0")/.."

ICON="apps/ios/Empezar/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
LOGO="apps/web/img/logo"
OG="apps/web/img/og"

for tool in magick rsvg-convert; do
  command -v "$tool" >/dev/null || { echo "error: $tool is required (brew install imagemagick librsvg)" >&2; exit 1; }
done

[ -f "$ICON" ] || { echo "error: missing app icon at $ICON" >&2; exit 1; }

mkdir -p "$LOGO" "$OG"

# --- Brand mark -------------------------------------------------------------
# The app icon is a white "e" on a blue rounded square. Threshold it into a
# clean silhouette so the mark can be inlined on light and dark surfaces.
for spec in "ink:#15213B" "white:#FFFFFF"; do
  name="${spec%%:*}"
  color="${spec##*:}"
  magick "$ICON" -colorspace gray -threshold 60% -trim +repage -resize 340x \
    -alpha copy -fill "$color" -colorize 100 "$LOGO/mark-$name-128.png"
done

# --- Icons ------------------------------------------------------------------
magick "$ICON" -resize 180x180 "$LOGO/apple-touch-icon.png"
magick "$ICON" -resize 192x192 "$LOGO/icon-192.png"
magick "$ICON" -resize 512x512 "$LOGO/icon-512.png"
magick "$ICON" -define icon:auto-resize=48,32,16 apps/web/favicon.ico

# Scalable favicon: blue rounded square with the mark embedded as a data URI.
mark_base64="$(base64 < "$LOGO/mark-white-128.png" | tr -d '\n')"
cat > apps/web/favicon.svg <<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="22" fill="#1757E0"/>
  <image x="15" y="20" width="70" height="57" href="data:image/png;base64,$mark_base64"/>
</svg>
SVG

# --- App screenshots --------------------------------------------------------
# The marketing pages use the illustrated screens in img/illustrations, so no
# raster screenshots are published. The captures in docs/screenshots are kept
# for documentation only.
rm -rf apps/web/img/app

# --- Book cover -------------------------------------------------------------
magick apps/web/img/cover.png -resize 800x -strip -quality 85 -interlace Plane apps/web/img/cover-800.jpg

# --- Open Graph cards -------------------------------------------------------
# The generator writes one SVG per page with the headline; rasterise it and
# stamp the brand mark on top.
for source in "$OG"/*.svg; do
  name="$(basename "$source" .svg)"
  rsvg-convert -w 1200 -b none "$source" -o "$OG/$name.png"
  magick "$OG/$name.png" \
    \( "$LOGO/mark-white-128.png" -resize 150x \) -geometry +88+54 -composite \
    -strip -quality 86 -interlace Plane "$OG/$name.jpg"
  rm -f "$OG/$name.png"
done

echo "Web assets rebuilt: $(ls "$OG"/*.jpg | wc -l | tr -d ' ') Open Graph cards, icons, favicon, brand mark and book cover."
