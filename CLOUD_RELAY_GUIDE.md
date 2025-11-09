# Cloud Relay Implementation Guide

## Overview

The Cloud Relay feature enables file transfers between devices that are **not** on the same local network by using a relay server as an intermediary. This is useful when:

- Devices are on different networks (e.g., home and office)
- One device is behind a restrictive firewall
- Direct P2P connection is not possible

## Architecture

```
Device A (Network 1) <--TLS--> Relay Server <--TLS--> Device B (Network 2)
```

### Security Model

- **End-to-End Encryption**: Files are encrypted on Device A before upload to relay
- **Temporary Storage**: Files deleted from relay immediately after Device B downloads
- **Access Tokens**: One-time-use tokens for each transfer
- **No Persistence**: Relay doesn't permanently store any file data

## Implementation Options

Since you don't have a commercial cloud server with API keys, here are several options:

### Option 1: Self-Hosted Relay Server (Recommended)

Deploy your own lightweight relay server on:
- **VPS** (DigitalOcean, Linode, Vultr): $5-10/month
- **AWS EC2 Free Tier**: First year free
- **Oracle Cloud Free Tier**: Permanent free tier
- **Home Server**: If you have static IP or DDNS

**Advantages:**
- Full control over data
- No API costs
- Simple Node.js/Python implementation
- Low resource requirements

**Implementation:**

```javascript
// Simple relay server (Node.js)
const express = require('express');
const multer = require('multer');
const crypto = require('crypto');

const app = express();
const uploads = new Map(); // In-memory storage

// Generate one-time token
app.post('/api/create-transfer', (req, res) => {
  const token = crypto.randomBytes(32).toString('hex');
  uploads.set(token, { status: 'pending', createdAt: Date.now() });
  res.json({ token, uploadUrl: `/api/upload/${token}` });
});

// Upload encrypted file
app.post('/api/upload/:token', multer().single('file'), (req, res) => {
  const transfer = uploads.get(req.params.token);
  if (!transfer) return res.status(404).send('Invalid token');
  
  transfer.data = req.file.buffer;
  transfer.status = 'ready';
  res.json({ success: true });
});

// Download and delete
app.get('/api/download/:token', (req, res) => {
  const transfer = uploads.get(req.params.token);
  if (!transfer || transfer.status !== 'ready') {
    return res.status(404).send('Not found');
  }
  
  res.send(transfer.data);
  uploads.delete(req.params.token); // Delete after download
});

// Cleanup old transfers (every 5 minutes)
setInterval(() => {
  const now = Date.now();
  for (const [token, transfer] of uploads.entries()) {
    if (now - transfer.createdAt > 3600000) { // 1 hour
      uploads.delete(token);
    }
  }
}, 300000);

app.listen(3000);
```

### Option 2: WebRTC + STUN/TURN Servers

Use WebRTC for direct P2P with public STUN servers:

- **Google STUN**: `stun:stun.l.google.com:19302` (FREE)
- **Free TURN**: Open Relay Project (limited)
- **Twilio TURN**: Free tier (250 MB/month)

**Advantages:**
- Direct P2P connection (faster)
- No file data through server
- Only signaling needs server

**Disadvantages:**
- More complex implementation
- May not work behind some firewalls

### Option 3: Peer-to-Peer with Signaling Server

Minimal signaling server that just exchanges connection info:

```javascript
// Signaling server (WebSocket)
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

const peers = new Map();

wss.on('connection', (ws) => {
  ws.on('message', (message) => {
    const data = JSON.parse(message);
    
    if (data.type === 'register') {
      peers.set(data.deviceId, ws);
    } else if (data.type === 'signal') {
      const targetWs = peers.get(data.targetDevice);
      if (targetWs) {
        targetWs.send(JSON.stringify(data));
      }
    }
  });
});
```

Devices exchange connection details, then establish direct TCP/UDP connection.

### Option 4: Temporary Storage Services

Use existing free storage APIs as relay:

1. **Cloudflare R2 Free Tier**: 10 GB storage, 1M reads/month
2. **Backblaze B2**: 10 GB free storage
3. **AWS S3 Free Tier**: 5 GB for first year

**Advantages:**
- No server management
- High reliability
- Global CDN

**Disadvantages:**
- Requires API keys
- More complex auth flow
- Rate limits

### Option 5: Email as Relay (Small Files)

For files < 25 MB, use email services:

```dart
// Send file via email API
Future<void> sendViaEmail(File file, String recipientDevice) async {
  // Encrypt file
  final encrypted = await encryptFile(file);
  
  // Send via SMTP/API
  await sendEmail(
    to: getDeviceEmail(recipientDevice),
    subject: 'RT-Transfer-${DateTime.now().millisecondsSinceEpoch}',
    attachment: encrypted,
  );
}
```

## Recommended Approach

**For Your Use Case:**

Since you don't have existing cloud infrastructure, I recommend **Option 1: Self-Hosted Relay**:

1. **Deploy to Oracle Cloud Free Tier** (permanent free):
   - 1-4 ARM Ampere A1 cores
   - 24 GB memory
   - 200 GB storage
   - 10 TB bandwidth/month

2. **Setup Script:**

```bash
# Install on Ubuntu 20.04
sudo apt update
sudo apt install nodejs npm

# Create relay server
cat > relay.js << 'EOF'
[Insert relay server code from above]
EOF

# Install dependencies
npm install express multer

# Run with PM2 for auto-restart
npm install -g pm2
pm2 start relay.js
pm2 startup
pm2 save
```

3. **Client Integration:**

```dart
// In transfer_service.dart
Future<void> transferViaRelay(Device device, Transfer transfer) async {
  // Request token from relay
  final response = await http.post(
    Uri.parse('https://your-relay.com/api/create-transfer'),
    body: jsonEncode({
      'sourceDevice': deviceManager.deviceId,
      'targetDevice': device.id,
    }),
  );
  
  final token = jsonDecode(response.body)['token'];
  
  // Encrypt file end-to-end
  final encryptedFile = await encryptFileForDevice(transfer.filePath, device);
  
  // Upload to relay
  await uploadToRelay(encryptedFile, token);
  
  // Notify target device (via existing discovery or push notification)
  await notifyDevice(device.id, token);
}
```

## Configuration

Add to settings:

```dart
class AppSettings {
  // ...existing settings...
  
  bool enableCloudRelay = false;
  String relayServerUrl = '';  // User configures their own relay
  
  // Fallback to relay if direct connection fails after X seconds
  int relayFallbackTimeout = 30;
}
```

## Security Considerations

1. **End-to-End Encryption**: Always encrypt before uploading
2. **Token Expiry**: Tokens valid for 1 hour max
3. **Single Use**: Delete after download
4. **Rate Limiting**: Prevent abuse
5. **Size Limits**: Cap at 5 GB per transfer

## Testing

```bash
# Test relay server
curl -X POST http://localhost:3000/api/create-transfer
# Returns: {"token": "abc123...", "uploadUrl": "/api/upload/abc123"}

# Upload file
curl -X POST http://localhost:3000/api/upload/abc123 \
  -F "file=@test.txt"

# Download file
curl http://localhost:3000/api/download/abc123 > received.txt
```

## Cost Analysis

| Solution | Setup Cost | Monthly Cost | Bandwidth |
|----------|------------|--------------|-----------|
| Oracle Free | $0 | $0 | 10 TB |
| AWS Free Tier | $0 | $0 (year 1) | 15 GB |
| DigitalOcean | $0 | $5 | 1 TB |
| Cloudflare R2 | $0 | $0.015/GB | None |

## Conclusion

For a no-cost solution, use **Oracle Cloud Free Tier** with the simple relay server implementation above. This gives you:

- ✅ No monthly costs
- ✅ Full control
- ✅ 10 TB bandwidth
- ✅ Simple implementation
- ✅ No API keys needed (you control the server)

Users can optionally configure their own relay server URL in settings if they want cloud relay functionality.
