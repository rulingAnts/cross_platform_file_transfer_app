# App Icons Generated

This document describes the app icons generated from `assets/icons/logo.svg`.

## Generation

Run the icon generation script:
```bash
./scripts/generate_icons.sh
```

The script uses Inkscape CLI to convert the SVG to various PNG sizes.

## Desktop App (Electron)

### macOS Icons
- `desktop_app/assets/icons/icon.icns` - macOS app icon bundle (121 KB)
- Generated from PNG sizes: 16, 32, 64, 128, 256, 512, 1024

### Windows Icons
- `desktop_app/assets/icons/win/icon-*.png` - Multiple sizes for Windows
- Sizes: 16, 24, 32, 48, 64, 128, 256
- Electron-builder will generate icon.ico automatically during build

### Main Icon
- `desktop_app/assets/icons/icon.png` - 512x512 main icon

## Mobile App (Android)

### Standard Launcher Icons
Generated in 5 density buckets following Material Design guidelines:
- `mipmap-mdpi/ic_launcher.png` - 48x48 (160dpi)
- `mipmap-hdpi/ic_launcher.png` - 72x72 (240dpi)
- `mipmap-xhdpi/ic_launcher.png` - 96x96 (320dpi)
- `mipmap-xxhdpi/ic_launcher.png` - 144x144 (480dpi)
- `mipmap-xxxhdpi/ic_launcher.png` - 192x192 (640dpi)

### Adaptive Icons (Android 8.0+)
Foreground layers for adaptive icons:
- `mipmap-mdpi/ic_launcher_foreground.png` - 108x108
- `mipmap-hdpi/ic_launcher_foreground.png` - 162x162
- `mipmap-xhdpi/ic_launcher_foreground.png` - 216x216
- `mipmap-xxhdpi/ic_launcher_foreground.png` - 324x324
- `mipmap-xxxhdpi/ic_launcher_foreground.png` - 432x432

Background: `drawable/ic_launcher_background.xml` (gradient)

### Round Icons
Alternative circular launcher icons:
- Generated for all 5 density buckets (mdpi through xxxhdpi)

## Usage

### Website
The `docs/favicon.ico` file is automatically used by browsers:
- Multi-resolution ICO file with 16x16, 32x32, and 48x48 sizes
- Referenced in HTML with `<link rel="icon" type="image/x-icon" href="favicon.ico">`

### Electron
The icons are automatically used by electron-builder when packaging:
- macOS: Uses `icon.icns`
- Windows: Generates `icon.ico` from PNG files
- Linux: Uses `icon.png`

### Android
Icons are referenced in `AndroidManifest.xml`:
```xml
<application
    android:icon="@mipmap/ic_launcher"
    android:roundIcon="@mipmap/ic_launcher_round"
    android:label="@string/app_name"
    ...>
```

Launcher icons are automatically included in both debug and release APK builds.

**Localized App Names:**
- English: "Rapid Transfer" (`res/values/strings.xml`)
- Indonesian: "Transfer Cepat" (`res/values-id/strings.xml`)

The system automatically displays the correct name based on device language.

**Adaptive Icons (Android 8.0+):**
- Defined in `res/mipmap-anydpi-v26/ic_launcher.xml`
- Uses foreground PNGs + gradient background drawable
- Supports various shapes (circle, squircle, rounded square) based on device manufacturer

## Customization

To regenerate with a different SVG:
1. Replace `assets/icons/logo.svg`
2. Run `./scripts/generate_icons.sh`

To adjust colors/gradients:
- Edit `ic_launcher_background.xml` for Android adaptive icon background
- Modify the SVG source for icon appearance changes
