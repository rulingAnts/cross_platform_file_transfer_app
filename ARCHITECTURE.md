# Technical Architecture

## Overview

Rapid Transfer is a peer-to-peer file transfer application designed for local network usage. It employs a decentralized architecture where each device acts as both a client and a server.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Network Layer                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │      UDP Broadcast Discovery (Port 8766)               │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │   TLS 1.3 Encrypted TCP Connections (Port 8765)        │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ▲ ▼
┌─────────────────────────────────────────────────────────────┐
│                   Application Layer                          │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │  Desktop (Node)  │◄───────►│ Mobile (Flutter) │          │
│  │                  │         │                  │          │
│  │ • UDP Discovery  │         │ • UDP Discovery  │          │
│  │ • Transfer       │         │ • Transfer       │          │
│  │ • Device Mgmt    │         │ • Device Mgmt    │          │
│  │ • File Handling  │         │ • File Handling  │          │
│  └──────────────────┘         └──────────────────┘          │
└─────────────────────────────────────────────────────────────┘
                            ▲ ▼
┌─────────────────────────────────────────────────────────────┐
│                      Storage Layer                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Temporary Files  │  Downloads  │  Configuration       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Desktop Application (Electron/Node.js)

### Components

#### Main Process (`src/main.js`)
- **Responsibilities:**
  - Window lifecycle management
  - Service initialization
  - IPC handler setup
  - Application menu
- **Key Dependencies:**
  - electron
  - Service modules

#### Services

**Discovery Service** (`src/services/discovery.js`)
- Uses Node.js `dgram` module for UDP broadcast
- Broadcasts device info on port 8766 every 5 seconds
- Listens for broadcasts from other devices
- Calculates broadcast addresses for local network interfaces
- Auto-cleanup of stale devices (30+ seconds)
- Manages device list updates

**Transfer Service** (`src/services/transfer.js`)
- TLS server management
- Connection handling
- Transfer orchestration
- Multi-stream coordination
- Checksum verification
- Resume logic

**Device Manager** (`src/services/deviceManager.js`)
- Device registry
- Trust management
- Alias management
- Settings persistence
- Configuration I/O

#### Renderer Process

**Preload** (`src/preload.js`)
- Context isolation bridge
- Secure IPC communication
- API exposure to renderer

**UI** (`src/ui/`)
- `index.html` - Main layout
- `styles.css` - Material Design inspired styles
- `renderer.js` - UI logic and event handling

### Data Flow

```
User Action → Renderer → IPC → Main Process → Service
                ↓                               ↓
            UI Update ← Event ← EventEmitter ← Service
```

## Mobile Application (Flutter/Dart)

### Architecture Pattern: Provider + Services

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  ┌───────────────────────────────────┐  │
│  │  Screens (HomeScreen, Settings)   │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Widgets (DeviceList, Queue)      │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                  ▲ ▼
┌─────────────────────────────────────────┐
│           Business Logic Layer          │
│  ┌───────────────────────────────────┐  │
│  │  Providers (ChangeNotifier)       │  │
│  │  • DeviceManager                  │  │
│  │  • TransferService                │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
                  ▲ ▼
┌─────────────────────────────────────────┐
│              Data Layer                 │
│  ┌───────────────────────────────────┐  │
│  │  Models (Device, FileTransfer)    │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │  Storage (SharedPreferences)      │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### Key Components

#### Models (`lib/models/`)
- `device.dart` - Device representation with metadata
- `transfer.dart` - Transfer state with progress tracking

#### Services (`lib/services/`)
- `device_manager.dart` - Device discovery and management
- `transfer_service.dart` - File transfer orchestration

#### Screens (`lib/screens/`)
- `home_screen.dart` - Main UI with device and transfer lists
- `settings_screen.dart` - Configuration interface

#### Widgets (`lib/widgets/`)
- `device_list.dart` - Scrollable device cards with selection
- `transfer_queue.dart` - Transfer items with progress bars

## Network Protocol

### Discovery Phase

1. **Broadcast** (every 5 seconds):
   ```json
   {
     "type": "rapidtransfer",
     "id": "device-uuid",
     "name": "Device Name",
     "platform": "android|darwin|win32",
     "version": "0.1.0",
     "port": 8765
   }
   ```

2. **Listen**: Collect broadcasts from other devices

3. **Update**: Maintain active device list

### Pairing Phase

When devices connect for the first time:

1. Generate random 3-digit code
2. Display on both devices
3. User confirms match
4. Exchange and pin certificates
5. Mark as trusted

```
Device A                     Device B
   │                            │
   ├──────► VERIFY_REQUEST ────►│
   │       (code: 123)          │
   │                            │
   │  [User confirms on both]   │
   │                            │
   │◄──── VERIFY_RESPONSE ──────┤
   │       (accepted: true)     │
   │                            │
   ├──────► TRUST_INFO ────────►│
   │       (public_key)         │
   │                            │
```

### Transfer Phase

```
Sender                                    Receiver
  │                                          │
  ├───► TRANSFER_REQUEST ──────────────────►│
  │     (file_info, checksum)               │
  │                                          │
  │◄──── TRANSFER_ACCEPT ────────────────────┤
  │     (ready: true)                        │
  │                                          │
  ├═══► CHUNK_DATA (stream 1) ═════════════►│
  ├═══► CHUNK_DATA (stream 2) ═════════════►│
  ├═══► CHUNK_DATA (stream 3) ═════════════►│
  │                                          │
  │◄──── CHUNK_ACK ──────────────────────────┤
  │     (chunk_id, checksum_ok)              │
  │                                          │
  │     ... continue until complete ...      │
  │                                          │
  │◄──── TRANSFER_COMPLETE ──────────────────┤
  │     (checksum_verified)                  │
  │                                          │
```

### Message Format

Binary protocol with header:
- 4 bytes: Length (uint32)
- 1 byte: Message type (uint8)
- N bytes: JSON payload

Message types:
- 0x01: VERIFY_REQUEST
- 0x02: VERIFY_RESPONSE
- 0x03: TRANSFER_REQUEST
- 0x04: TRANSFER_ACCEPT
- 0x05: CHUNK_DATA
- 0x06: CHUNK_ACK
- 0x07: TRANSFER_COMPLETE
- 0x08: ERROR

## Multi-Stream Strategy

### Stream Allocation

Based on file size:
- < 10 MB: 1 stream
- 10-100 MB: 2 streams
- 100 MB - 1 GB: 4 streams
- \> 1 GB: 6 streams

Can be manually configured (1-8 streams).

### Dynamic Adjustment

Monitor throughput every 5 seconds:
- If speed < 10 Mbps and can add streams: add 1 stream
- If stream count > optimal and speed plateaued: remove 1 stream

### Fair Distribution

When sending to multiple devices simultaneously:
```
Total Available Streams: 6
Active Transfers: 2 (Device A, Device B)
Distribution: 3 streams to A, 3 streams to B
```

## File Handling

### Sender Workflow

```
1. User selects file/folder
2. Copy to ~/.rapidtransfer/temp/
3. If folder: tar -czf file.tar.gz folder/
4. Calculate SHA-256 checksum
5. Split into 1MB chunks
6. Create manifest
7. Send to receiver
8. Wait for confirmation
9. Delete temp files
```

### Receiver Workflow

```
1. Receive transfer request
2. Check available space
3. Accept transfer
4. Receive chunks to ~/.rapidtransfer/incoming/
5. Verify chunk checksums
6. After all chunks: verify full file checksum
7. If folder: extract tar.gz
8. Move to ~/Downloads/
9. Delete temp files
10. Notify user
```

### Resume Mechanism

Manifest format (`transfer_manifest.json`):
```json
{
  "transfer_id": "uuid",
  "file_name": "document.pdf",
  "file_size": 5242880,
  "checksum": "sha256...",
  "chunk_size": 1048576,
  "total_chunks": 5,
  "chunks": [
    {"index": 0, "size": 1048576, "checksum": "...", "received": true},
    {"index": 1, "size": 1048576, "checksum": "...", "received": true},
    {"index": 2, "size": 1048576, "checksum": "...", "received": false},
    {"index": 3, "size": 1048576, "checksum": "...", "received": false},
    {"index": 4, "size": 1048576, "checksum": "...", "received": false}
  ],
  "created_at": "2025-11-09T06:00:00Z",
  "last_activity": "2025-11-09T06:05:00Z"
}
```

## Security Model

### Threat Mitigation

| Threat | Mitigation |
|--------|------------|
| Eavesdropping | TLS 1.3 encryption |
| MITM | Certificate pinning |
| Unauthorized access | Device pairing with verification |
| Data tampering | SHA-256 checksums |
| Replay attacks | Unique transfer IDs + timestamps |

### Trust Levels

1. **Unknown**: Requires verification before any transfer
2. **Verified**: Code confirmed, certificate pinned
3. **Trusted**: Can auto-accept if setting enabled

## Performance Considerations

### Memory Management
- Stream data in chunks (1 MB)
- Release chunks after verification
- Keep max 3 chunks in memory per stream
- Clean up temp files immediately

### CPU Usage
- Checksum calculation in background
- Compression in separate thread/isolate
- UI updates throttled to 60 FPS

### Network Optimization
- TCP_NODELAY for low latency
- SO_KEEPALIVE for connection monitoring
- Adaptive buffer sizes
- Connection pooling

## Error Handling

### Recovery Strategies

**Connection Lost:**
1. Pause transfer
2. Save state to manifest
3. Retry every 10 seconds for 5 minutes
4. If reconnect: resume from last chunk
5. If timeout: mark as paused

**Checksum Mismatch:**
1. Retry chunk up to 3 times
2. If still fails: mark transfer as failed
3. Offer retry option to user

**Storage Full:**
1. Check before accepting transfer
2. If mid-transfer: pause and notify
3. Allow user to free space
4. Resume when space available

## Localization

### Translation Keys

Structure: `category_item_variant`

Examples:
- `button_send`
- `label_device_name`
- `message_transfer_complete`

### Indonesian Guidelines

- Use common words, avoid technical jargon
- Short phrases over long sentences
- Icons to supplement text
- Tooltips for additional context

## Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Service logic (device management, transfer calculations)
- Utility functions (checksums, file operations)

### Integration Tests
- Device discovery flow
- Full transfer cycle
- Resume mechanism
- Error scenarios

### Platform Tests
- Android ↔ Android
- Android ↔ macOS
- Android ↔ Windows
- macOS ↔ Windows

### Performance Tests
- 10 MB file (baseline)
- 1 GB file (sustained transfer)
- 10 GB file (long-running)
- Multiple simultaneous transfers
- Resume after interruption

## Deployment

### Desktop
- macOS: Sign and notarize DMG
- Windows: Sign NSIS installer
- Auto-update via electron-updater

### Mobile
- Android: Sign APK/AAB with release key
- Distribute via Play Store or direct download
- Version updates via in-app notification

## Future Enhancements

1. **iOS Support**: Native iOS app with similar features
2. **Cloud Relay**: Transfer across different networks
3. **QR Code Pairing**: Scan to connect
4. **Bandwidth Limiting**: User-configurable speed caps
5. **Transfer History**: Searchable log of past transfers
6. **Compression Options**: Let user choose compression level
7. **Multiple Receivers**: Send same file to many devices efficiently
8. **Scheduled Transfers**: Queue transfers for specific times
