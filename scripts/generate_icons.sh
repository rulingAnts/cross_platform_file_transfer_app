#!/usr/bin/env bash
# Generate app icons for Electron (Mac/Windows) and Android from SVG
# Uses Inkscape for SVG to PNG conversion

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SVG_SOURCE="$ROOT_DIR/assets/icons/logo.svg"
INKSCAPE="/Applications/Inkscape.app/Contents/MacOS/inkscape"

log() { echo -e "\033[1;36m[icon-gen]\033[0m $*"; }
err() { echo -e "\033[1;31m[icon-gen][error]\033[0m $*" 1>&2; }

# Check if source SVG exists
if [[ ! -f "$SVG_SOURCE" ]]; then
  err "Source SVG not found: $SVG_SOURCE"
  exit 1
fi

# Check if Inkscape is available
if [[ ! -x "$INKSCAPE" ]]; then
  err "Inkscape not found at: $INKSCAPE"
  err "Please install Inkscape or update INKSCAPE path in this script"
  exit 1
fi

log "Using Inkscape: $INKSCAPE"
log "Source SVG: $SVG_SOURCE"

# Function to generate PNG from SVG
generate_png() {
  local size=$1
  local output=$2
  local output_dir=$(dirname "$output")
  
  mkdir -p "$output_dir"
  
  log "Generating ${size}x${size} → $output"
  "$INKSCAPE" \
    --export-type=png \
    --export-filename="$output" \
    --export-width=$size \
    --export-height=$size \
    "$SVG_SOURCE" >/dev/null 2>&1
}

# ============================================================================
# ELECTRON ICONS (Desktop App)
# ============================================================================
log ""
log "Generating Electron icons..."

DESKTOP_ICONS="$ROOT_DIR/desktop_app/assets/icons"

# macOS icons (icon.icns will be generated from icon.png)
# Generate multiple sizes for best quality
generate_png 16 "$DESKTOP_ICONS/icon@16.png"
generate_png 32 "$DESKTOP_ICONS/icon@32.png"
generate_png 64 "$DESKTOP_ICONS/icon@64.png"
generate_png 128 "$DESKTOP_ICONS/icon@128.png"
generate_png 256 "$DESKTOP_ICONS/icon@256.png"
generate_png 512 "$DESKTOP_ICONS/icon@512.png"
generate_png 1024 "$DESKTOP_ICONS/icon@1024.png"

# Main icon for Electron
generate_png 512 "$DESKTOP_ICONS/icon.png"

# Windows icon (icon.ico will be generated from these)
generate_png 16 "$DESKTOP_ICONS/win/icon-16.png"
generate_png 24 "$DESKTOP_ICONS/win/icon-24.png"
generate_png 32 "$DESKTOP_ICONS/win/icon-32.png"
generate_png 48 "$DESKTOP_ICONS/win/icon-48.png"
generate_png 64 "$DESKTOP_ICONS/win/icon-64.png"
generate_png 128 "$DESKTOP_ICONS/win/icon-128.png"
generate_png 256 "$DESKTOP_ICONS/win/icon-256.png"

# ============================================================================
# ANDROID ICONS (Mobile App)
# ============================================================================
log ""
log "Generating Android launcher icons..."

ANDROID_RES="$ROOT_DIR/mobile_app/android/app/src/main/res"

# Android launcher icons (Material Design guidelines)
# mipmap-mdpi (48x48 @ 1x)
generate_png 48 "$ANDROID_RES/mipmap-mdpi/ic_launcher.png"

# mipmap-hdpi (72x72 @ 1.5x)
generate_png 72 "$ANDROID_RES/mipmap-hdpi/ic_launcher.png"

# mipmap-xhdpi (96x96 @ 2x)
generate_png 96 "$ANDROID_RES/mipmap-xhdpi/ic_launcher.png"

# mipmap-xxhdpi (144x144 @ 3x)
generate_png 144 "$ANDROID_RES/mipmap-xxhdpi/ic_launcher.png"

# mipmap-xxxhdpi (192x192 @ 4x)
generate_png 192 "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher.png"

# Android Adaptive Icons (foreground + background)
# For simplicity, we'll use the same icon as foreground
# You may want to create a separate background layer

# Foreground (108dp, safe zone 72dp)
generate_png 108 "$ANDROID_RES/mipmap-mdpi/ic_launcher_foreground.png"
generate_png 162 "$ANDROID_RES/mipmap-hdpi/ic_launcher_foreground.png"
generate_png 216 "$ANDROID_RES/mipmap-xhdpi/ic_launcher_foreground.png"
generate_png 324 "$ANDROID_RES/mipmap-xxhdpi/ic_launcher_foreground.png"
generate_png 432 "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher_foreground.png"

# Round icons (alternative launcher icon shape)
generate_png 48 "$ANDROID_RES/mipmap-mdpi/ic_launcher_round.png"
generate_png 72 "$ANDROID_RES/mipmap-hdpi/ic_launcher_round.png"
generate_png 96 "$ANDROID_RES/mipmap-xhdpi/ic_launcher_round.png"
generate_png 144 "$ANDROID_RES/mipmap-xxhdpi/ic_launcher_round.png"
generate_png 192 "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher_round.png"

# ============================================================================
# POST-PROCESSING NOTES
# ============================================================================
log ""
log "✓ Icon generation complete!"
log ""
log "Next steps:"
log "  1. For macOS .icns: Use 'iconutil' or electron-builder will auto-generate"
log "  2. For Windows .ico: Use 'electron-builder' or a tool like ImageMagick"
log "  3. Android icons are ready to use"
log ""
log "To generate .icns for macOS (optional, electron-builder handles this):"
log "  mkdir icon.iconset"
log "  cp $DESKTOP_ICONS/icon@16.png icon.iconset/icon_16x16.png"
log "  cp $DESKTOP_ICONS/icon@32.png icon.iconset/icon_16x16@2x.png"
log "  cp $DESKTOP_ICONS/icon@32.png icon.iconset/icon_32x32.png"
log "  cp $DESKTOP_ICONS/icon@64.png icon.iconset/icon_32x32@2x.png"
log "  cp $DESKTOP_ICONS/icon@128.png icon.iconset/icon_128x128.png"
log "  cp $DESKTOP_ICONS/icon@256.png icon.iconset/icon_128x128@2x.png"
log "  cp $DESKTOP_ICONS/icon@256.png icon.iconset/icon_256x256.png"
log "  cp $DESKTOP_ICONS/icon@512.png icon.iconset/icon_256x256@2x.png"
log "  cp $DESKTOP_ICONS/icon@512.png icon.iconset/icon_512x512.png"
log "  cp $DESKTOP_ICONS/icon@1024.png icon.iconset/icon_512x512@2x.png"
log "  iconutil -c icns icon.iconset -o $DESKTOP_ICONS/icon.icns"
log "  rm -rf icon.iconset"
log ""
log "Android adaptive icon background (if needed):"
log "  Create a solid color or gradient background in:"
log "  $ANDROID_RES/drawable/ic_launcher_background.xml"
log ""
