# Changelog

All notable changes to the Rapid Transfer project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Desktop App (Electron/Node.js)
- Initial Electron application structure
- Main window with responsive layout
- Device discovery panel with card-based UI
- Drag-and-drop file transfer zone
- Transfer queue with progress tracking
- Settings modal with comprehensive options
- Device verification modal with code display
- mDNS/Bonjour service discovery infrastructure
- TLS server for secure transfers
- Device management with trust/alias support
- Configuration persistence in `~/.rapidtransfer`
- Beautiful Material Design inspired UI
- Icon-driven interface for better accessibility

#### Mobile App (Flutter/Android)
- Flutter application structure with Provider state management
- Home screen with device list and transfer queue
- Settings screen with all configuration options
- Device list widget with selection support
- Transfer queue widget with progress indicators
- Device and Transfer models
- Device manager service with SharedPreferences persistence
- Transfer service with queue management
- Localization support (English and Indonesian)
- Material Design 3 theming
- Responsive layouts for different screen sizes

#### Localization
- English (en) translations
- Indonesian (id) translations with Papuan-friendly terminology
- L10n configuration for Flutter
- Translation files in ARB format

#### Documentation
- Comprehensive main README with project overview
- Desktop app README with build instructions
- Mobile app README with development guide
- Architecture documentation
- Security and network protocol specifications
- Contribution guidelines

#### Project Infrastructure
- Build scripts for Android APK and AAB
- ESLint configuration for desktop app
- Git repository with proper .gitignore
- Package management (npm for desktop, pub for mobile)

### Architecture Highlights

#### Network Layer
- mDNS service type: `_rapidtransfer._tcp.local.`
- TCP with TLS 1.3 for transfers
- Multi-stream support (1-8 streams)
- Chunk-based transfers (1 MB chunks)
- SHA-256 checksumming

#### Security
- Device verification with 3-digit codes
- Certificate pinning after pairing
- TLS 1.3 encryption
- No password storage
- Trust management

#### User Experience
- Zero-configuration device discovery
- Icon-driven UI with minimal text
- Bilingual support (EN/ID)
- Progress tracking with ETA
- Resume capability (infrastructure in place)

## [0.1.0] - 2025-11-09

### Initial Release
- Project initialized with basic structure
- Desktop and mobile app foundations
- Core services and UI components
- Documentation and build scripts

---

## Development Status

### Completed ✅
- Project structure and organization
- UI/UX design and implementation
- Service layer architecture
- State management
- Localization framework
- Settings persistence
- Device management
- Basic transfer service structure
- Documentation

### In Progress 🚧
- Network protocol implementation
- Multi-stream transfer logic
- File compression/decompression
- Resume mechanism
- Checksum verification
- Connection handling
- Error recovery

### Planned 📋
- Share intent handling (Android)
- File picker integration
- Hotspot mode
- WiFi Direct support
- Wake lock management
- Battery monitoring
- Integration testing
- Performance optimization
- Cross-platform testing

---

## Notes

This is the initial implementation focusing on:
1. **Solid architecture** - Clean separation of concerns, testable code
2. **User experience** - Beautiful, intuitive interfaces
3. **Localization** - Proper i18n support from day one
4. **Security** - TLS and verification built-in
5. **Documentation** - Comprehensive guides for users and developers

The core transfer protocol and network features are the next focus areas.
