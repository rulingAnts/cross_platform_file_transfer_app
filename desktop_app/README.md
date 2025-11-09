# Rapid Transfer Desktop App

Cross-platform desktop application for rapid file transfer over local networks.

## Features

- **Zero-config device discovery** using UDP broadcast
- **Multi-stream parallel transfers** for maximum speed
- **TLS 1.3 encryption** for secure transfers
- **Device pairing** with verification codes
- **Drag-and-drop** file transfer
- **Resume capability** for interrupted transfers
- **Cross-platform** support (macOS, Windows)

## Development

### Prerequisites

- Node.js 20 or higher
- npm 10 or higher

### Setup

```bash
cd desktop_app
npm install
```

### Running in Development

```bash
npm start
```

### Building

Build for your current platform:
```bash
npm run build
```

Build for macOS:
```bash
npm run build:mac
```

Build for Windows:
```bash
npm run build:win
```

Build for all platforms:
```bash
npm run build:all
```

## Architecture

- **Main Process** (`src/main.js`): Electron main process, manages windows and services
- **Preload** (`src/preload.js`): Bridge between main and renderer processes
- **Services**:
  - `discovery.js`: UDP broadcast device discovery
  - `transfer.js`: File transfer management
  - `deviceManager.js`: Device and settings management
- **UI** (`src/ui/`): HTML/CSS/JavaScript renderer process

## Configuration

User configuration is stored in `~/.rapidtransfer/config.json` and includes:
- Device ID and name
- Trusted devices
- Device aliases
- Settings (stream count, language, notifications, etc.)

## Security

- All transfers use TLS 1.3 encryption
- Certificate pinning after first pairing
- Device verification with random codes
- No passwords stored

## License

MIT
