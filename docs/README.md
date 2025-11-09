# Rapid Transfer Website

This directory contains the user-facing website for Rapid Transfer, designed to be hosted on GitHub Pages.

## Setup GitHub Pages

1. Go to your repository settings
2. Navigate to "Pages" in the left sidebar
3. Under "Build and deployment":
   - **Source**: Deploy from a branch
   - **Branch**: Select your branch (e.g., `main` or `copilot/add-localization-support`)
   - **Folder**: Select `/docs`
4. Click "Save"

GitHub will automatically build and deploy your site to:
`https://rulingants.github.io/cross_platform_file_transfer_app/`

## Files

- `index.html` - Main landing page with features, downloads, and documentation
- `privacy.html` - Privacy policy page
- `style.css` - Complete stylesheet for both pages

## Features

### Main Page
- Hero section with call-to-action
- Feature highlights (9 key features)
- How it works (3-step process)
- Download section (Windows, macOS, Android)
- Screenshots gallery
- Technical specifications
- Documentation links
- FAQ section
- Footer with links

### Privacy Page
- Complete privacy policy
- Data collection transparency
- Security information
- Open source verification

## Customization

### Update Download Links
When builds are ready, replace the placeholder links in `index.html`:

```html
<!-- Line ~180, 191, 202 -->
<a href="https://github.com/rulingAnts/cross_platform_file_transfer_app/releases/download/v1.0.0/RapidTransfer-Setup.exe" class="btn btn-download">
```

### Add Screenshots
Replace placeholder screenshots by:
1. Taking actual screenshots of the mobile app and history screen
2. Uploading to GitHub issues or releases
3. Updating the `<img src="">` tags in `index.html`

### Update Version Numbers
Update version numbers in the download cards:
```html
<p class="version">Version 1.0.0</p>
```

## Design

- **Color Scheme**: Primary blue (#4285F4), with purple gradient hero
- **Typography**: System fonts for optimal performance
- **Responsive**: Mobile-friendly design
- **Accessibility**: Semantic HTML, good contrast ratios
- **Performance**: No external dependencies, pure HTML/CSS

## Maintenance

The website is static HTML/CSS with no JavaScript dependencies (except for the download alert). It should work on all modern browsers and require minimal maintenance.

## License

Same as the main project (MIT License).
