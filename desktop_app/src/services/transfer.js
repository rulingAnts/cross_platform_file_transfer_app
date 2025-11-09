const EventEmitter = require('events');
const net = require('net');
const tls = require('tls');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const { pipeline } = require('stream/promises');
const archiver = require('archiver');
const tar = require('tar');

class TransferService extends EventEmitter {
  constructor(deviceManager) {
    super();
    this.deviceManager = deviceManager;
    this.server = null;
    this.port = 8765;
    this.transfers = new Map();
    this.connections = new Map();
    this.verificationCodes = new Map();
    this.tempDir = null;
  }

  async start() {
    try {
      // Create temp directory
      const os = require('os');
      this.tempDir = path.join(os.tmpdir(), 'rapidtransfer');
      await fs.mkdir(this.tempDir, { recursive: true });

      // Create TLS server
      const options = await this.generateSelfSignedCert();
      
      this.server = tls.createServer(options, (socket) => {
        this.handleConnection(socket);
      });

      this.server.listen(this.port, () => {
        console.log(`Transfer service listening on port ${this.port}`);
      });

      this.server.on('error', (err) => {
        console.error('Transfer service error:', err);
      });

    } catch (err) {
      console.error('Failed to start transfer service:', err);
      throw err;
    }
  }

  async generateSelfSignedCert() {
    const forge = require('node-forge');
    const pki = forge.pki;

    // Generate a key pair
    const keys = pki.rsa.generateKeyPair(2048);

    // Create a certificate
    const cert = pki.createCertificate();
    cert.publicKey = keys.publicKey;
    cert.serialNumber = '01';
    cert.validity.notBefore = new Date();
    cert.validity.notAfter = new Date();
    cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 10);

    const attrs = [{
      name: 'commonName',
      value: 'RapidTransfer'
    }];

    cert.setSubject(attrs);
    cert.setIssuer(attrs);
    cert.sign(keys.privateKey);

    // Convert to PEM format
    const pemCert = pki.certificateToPem(cert);
    const pemKey = pki.privateKeyToPem(keys.privateKey);

    return {
      key: pemKey,
      cert: pemCert,
      rejectUnauthorized: false // We'll do our own verification
    };
  }

  handleConnection(socket) {
    const connectionId = `${socket.remoteAddress}:${socket.remotePort}`;
    console.log('New connection:', connectionId);

    let buffer = Buffer.alloc(0);

    socket.on('data', (data) => {
      buffer = Buffer.concat([buffer, data]);
      this.processBuffer(socket, buffer);
    });

    socket.on('end', () => {
      console.log('Connection ended:', connectionId);
      this.connections.delete(connectionId);
    });

    socket.on('error', (err) => {
      console.error('Socket error:', err);
      this.connections.delete(connectionId);
    });
  }

  processBuffer(socket, buffer) {
    // Simple protocol: [length:4][type:1][data]
    while (buffer.length >= 5) {
      const length = buffer.readUInt32BE(0);
      if (buffer.length < 4 + length) {
        break; // Wait for more data
      }

      const type = buffer.readUInt8(4);
      const data = buffer.slice(5, 4 + length);
      buffer = buffer.slice(4 + length);

      this.handleMessage(socket, type, data);
    }
  }

  handleMessage(socket, type, data) {
    try {
      const message = JSON.parse(data.toString());
      
      switch (type) {
        case 1: // VERIFY_REQUEST
          this.handleVerifyRequest(socket, message);
          break;
        case 2: // VERIFY_RESPONSE
          this.handleVerifyResponse(socket, message);
          break;
        case 3: // TRANSFER_REQUEST
          this.handleTransferRequest(socket, message);
          break;
        case 4: // TRANSFER_ACCEPT
          this.handleTransferAccept(socket, message);
          break;
        case 5: // CHUNK_DATA
          this.handleChunkData(socket, message);
          break;
        case 6: // CHUNK_ACK
          this.handleChunkAck(socket, message);
          break;
        default:
          console.warn('Unknown message type:', type);
      }
    } catch (err) {
      console.error('Error handling message:', err);
    }
  }

  async sendFiles(deviceIds, filePaths) {
    const transfers = [];

    for (const deviceId of deviceIds) {
      const device = this.deviceManager.getDevice(deviceId);
      if (!device) {
        console.error('Device not found:', deviceId);
        continue;
      }

      // Check if device is trusted
      if (!this.deviceManager.isTrusted(deviceId)) {
        // Generate verification code
        const code = this.generateVerificationCode();
        this.verificationCodes.set(deviceId, {
          code,
          expiresAt: Date.now() + 300000 // 5 minutes
        });
        this.emit('verification-required', deviceId, code);
        
        // Wait for verification or timeout
        // This is simplified - in real implementation, use proper async handling
        continue;
      }

      for (const filePath of filePaths) {
        const transferId = crypto.randomBytes(16).toString('hex');
        const transfer = {
          id: transferId,
          deviceId,
          filePath,
          status: 'pending',
          progress: 0,
          createdAt: Date.now()
        };

        this.transfers.set(transferId, transfer);
        transfers.push(transfer);

        // Start transfer in background
        this.startTransfer(transfer).catch(err => {
          console.error('Transfer failed:', err);
          transfer.status = 'failed';
          transfer.error = err.message;
          this.emit('transfer-error', transfer, err);
        });
      }
    }

    return transfers;
  }

  async startTransfer(transfer) {
    transfer.status = 'preparing';
    this.emit('transfer-progress', transfer);

    // Get file stats
    const stats = await fs.stat(transfer.filePath);
    transfer.size = stats.size;
    transfer.isDirectory = stats.isDirectory();

    // Copy file to temp directory
    const tempPath = path.join(this.tempDir, path.basename(transfer.filePath));
    
    if (transfer.isDirectory) {
      // Compress directory
      transfer.status = 'compressing';
      this.emit('transfer-progress', transfer);
      
      const tarPath = `${tempPath}.tar.gz`;
      await this.compressDirectory(transfer.filePath, tarPath);
      transfer.tempPath = tarPath;
      transfer.size = (await fs.stat(tarPath)).size;
    } else {
      await fs.copyFile(transfer.filePath, tempPath);
      transfer.tempPath = tempPath;
    }

    // Calculate checksum
    transfer.status = 'checksumming';
    this.emit('transfer-progress', transfer);
    transfer.checksum = await this.calculateChecksum(transfer.tempPath);

    // Connect to device and start transfer
    transfer.status = 'connecting';
    this.emit('transfer-progress', transfer);

    const device = this.deviceManager.getDevice(transfer.deviceId);
    await this.connectAndTransfer(device, transfer);
  }

  async compressDirectory(dirPath, outputPath) {
    await tar.create(
      {
        gzip: true,
        file: outputPath,
        cwd: path.dirname(dirPath)
      },
      [path.basename(dirPath)]
    );
  }

  async calculateChecksum(filePath) {
    const hash = crypto.createHash('sha256');
    const stream = require('fs').createReadStream(filePath);
    
    return new Promise((resolve, reject) => {
      stream.on('data', (data) => hash.update(data));
      stream.on('end', () => resolve(hash.digest('hex')));
      stream.on('error', reject);
    });
  }

  async connectAndTransfer(device, transfer) {
    // This is a simplified version
    // Real implementation would handle multi-stream, chunking, etc.
    transfer.status = 'transferring';
    transfer.progress = 0;
    this.emit('transfer-progress', transfer);

    // Simulate transfer for now
    const interval = setInterval(() => {
      transfer.progress += 10;
      if (transfer.progress >= 100) {
        transfer.progress = 100;
        transfer.status = 'completed';
        clearInterval(interval);
        this.emit('transfer-complete', transfer);
      } else {
        this.emit('transfer-progress', transfer);
      }
    }, 500);
  }

  generateVerificationCode() {
    return Math.floor(100 + Math.random() * 900).toString();
  }

  async verifyDevice(deviceId, accept) {
    const verification = this.verificationCodes.get(deviceId);
    if (!verification) {
      return false;
    }

    if (Date.now() > verification.expiresAt) {
      this.verificationCodes.delete(deviceId);
      return false;
    }

    if (accept) {
      // In real implementation, exchange and store public keys
      await this.deviceManager.trustDevice(deviceId, 'publickey');
      this.verificationCodes.delete(deviceId);
      return true;
    } else {
      this.verificationCodes.delete(deviceId);
      return false;
    }
  }

  handleVerifyRequest(socket, message) {
    // Handle incoming verification request
    const code = this.generateVerificationCode();
    this.emit('verification-required', message.deviceId, code);
  }

  handleVerifyResponse(socket, message) {
    // Handle verification response
  }

  handleTransferRequest(socket, message) {
    // Handle incoming transfer request
  }

  handleTransferAccept(socket, message) {
    // Handle transfer acceptance
  }

  handleChunkData(socket, message) {
    // Handle incoming chunk data
  }

  handleChunkAck(socket, message) {
    // Handle chunk acknowledgment
  }

  getTransfers() {
    return Array.from(this.transfers.values());
  }

  async pauseTransfer(transferId) {
    const transfer = this.transfers.get(transferId);
    if (transfer && transfer.status === 'transferring') {
      transfer.status = 'paused';
      this.emit('transfer-progress', transfer);
      return true;
    }
    return false;
  }

  async resumeTransfer(transferId) {
    const transfer = this.transfers.get(transferId);
    if (transfer && transfer.status === 'paused') {
      // Restart transfer
      this.startTransfer(transfer).catch(err => {
        console.error('Resume failed:', err);
      });
      return true;
    }
    return false;
  }

  async cancelTransfer(transferId) {
    const transfer = this.transfers.get(transferId);
    if (transfer) {
      transfer.status = 'cancelled';
      // Clean up temp files
      if (transfer.tempPath) {
        try {
          await fs.unlink(transfer.tempPath);
        } catch (err) {
          console.error('Failed to delete temp file:', err);
        }
      }
      this.emit('transfer-progress', transfer);
      this.transfers.delete(transferId);
      return true;
    }
    return false;
  }

  stop() {
    if (this.server) {
      this.server.close();
    }
    console.log('Transfer service stopped');
  }
}

module.exports = TransferService;
