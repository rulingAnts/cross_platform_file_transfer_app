const EventEmitter = require('events');
const net = require('net');
const tls = require('tls');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const { pipeline } = require('stream/promises');
const archiver = require('archiver');
const tar = require('tar');
const NetworkMonitor = require('./networkMonitor');

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
    this.networkMonitor = new NetworkMonitor();
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
    try {
      // Connect to device
      const socket = await this.connectToDevice(device);
      transfer.socket = socket;
      
      // Send transfer request
      await this.sendMessage(socket, 3, {
        transferId: transfer.id,
        fileName: path.basename(transfer.filePath),
        fileSize: transfer.size,
        checksum: transfer.checksum,
        isDirectory: transfer.isDirectory
      });
      
      // Wait for acceptance
      await this.waitForAcceptance(socket, transfer);
      
      // Calculate stream count based on file size
      const streamCount = this.calculateStreamCount(transfer.size);
      
      // Split file into chunks
      const chunkSize = 1024 * 1024; // 1 MB
      const chunks = Math.ceil(transfer.size / chunkSize);
      
      transfer.status = 'transferring';
      transfer.progress = 0;
      transfer.chunks = chunks;
      transfer.sentChunks = 0;
      this.emit('transfer-progress', transfer);
      
      // Send chunks
      await this.sendFileChunks(socket, transfer, chunkSize, streamCount);
      
      // Mark complete
      transfer.status = 'completed';
      transfer.progress = 100;
      this.emit('transfer-complete', transfer);
      
      // Cleanup
      if (transfer.tempPath) {
        await fs.unlink(transfer.tempPath).catch(() => {});
      }
      
    } catch (err) {
      transfer.status = 'failed';
      transfer.error = err.message;
      this.emit('transfer-error', transfer, err);
      throw err;
    }
  }
  
  async connectToDevice(device) {
    return new Promise((resolve, reject) => {
      const socket = tls.connect({
        host: device.address,
        port: device.port,
        rejectUnauthorized: false
      }, () => {
        console.log('Connected to device:', device.id);
        resolve(socket);
      });
      
      socket.on('error', (err) => {
        reject(err);
      });
      
      socket.setTimeout(30000); // 30 second timeout
      socket.on('timeout', () => {
        socket.destroy();
        reject(new Error('Connection timeout'));
      });
    });
  }
  
  async sendMessage(socket, type, data) {
    const jsonData = JSON.stringify(data);
    const dataBuffer = Buffer.from(jsonData);
    const length = dataBuffer.length + 1; // +1 for type byte
    
    const message = Buffer.allocUnsafe(4 + 1 + dataBuffer.length);
    message.writeUInt32BE(length, 0);
    message.writeUInt8(type, 4);
    dataBuffer.copy(message, 5);
    
    return new Promise((resolve, reject) => {
      socket.write(message, (err) => {
        if (err) reject(err);
        else resolve();
      });
    });
  }
  
  async waitForAcceptance(socket, transfer) {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error('Transfer acceptance timeout'));
      }, 30000);
      
      const handler = (data) => {
        try {
          const type = data.readUInt8(4);
          if (type === 4) { // TRANSFER_ACCEPT
            clearTimeout(timeout);
            socket.removeListener('data', handler);
            resolve();
          }
        } catch (err) {
          // Ignore parsing errors, wait for correct message
        }
      };
      
      socket.on('data', handler);
    });
  }
  
  calculateStreamCount(fileSize) {
    if (fileSize < 10 * 1024 * 1024) return 1; // < 10 MB
    if (fileSize < 100 * 1024 * 1024) return 2; // < 100 MB
    if (fileSize < 1024 * 1024 * 1024) return 4; // < 1 GB
    return 6; // >= 1 GB
  }
  
  async sendFileChunks(socket, transfer, chunkSize, streamCount) {
    const fs = require('fs');
    const fileSize = transfer.size;
    const totalChunks = Math.ceil(fileSize / chunkSize);
    
    let chunkIndex = 0;
    let totalSent = 0;
    const startTime = Date.now();
    
    // For multi-stream, we'll send chunks in parallel batches
    const chunksPerStream = Math.ceil(totalChunks / streamCount);
    
    // Read file in chunks
    const readChunk = async (index) => {
      return new Promise((resolve, reject) => {
        const start = index * chunkSize;
        const end = Math.min(start + chunkSize, fileSize);
        const stream = fs.createReadStream(transfer.tempPath, { start, end: end - 1 });
        
        const chunks = [];
        stream.on('data', chunk => chunks.push(chunk));
        stream.on('end', () => resolve(Buffer.concat(chunks)));
        stream.on('error', reject);
      });
    };
    
    // Send chunks with parallelism and retry logic
    const sendBatch = async (batchStart, batchSize, maxRetries = 3) => {
      const promises = [];
      
      for (let i = 0; i < batchSize && (batchStart + i) < totalChunks; i++) {
        const idx = batchStart + i;
        
        promises.push((async () => {
          let retryCount = 0;
          
          while (retryCount < maxRetries) {
            try {
              const chunk = await readChunk(idx);
              const chunkHash = crypto.createHash('sha256').update(chunk).digest('hex');
              
              await this.sendChunkData(socket, {
                transferId: transfer.id,
                chunkIndex: idx,
                data: chunk.toString('base64'),
                checksum: chunkHash
              });
              
              await this.waitForChunkAck(socket, idx, 5000);
              
              return chunk.length;
            } catch (error) {
              retryCount++;
              console.error(`Chunk ${idx} failed (attempt ${retryCount}/${maxRetries}):`, error.message);
              
              if (retryCount >= maxRetries) {
                throw new Error(`Chunk ${idx} failed after ${maxRetries} retries`);
              }
              
              // Wait before retry with exponential backoff
              await new Promise(resolve => setTimeout(resolve, 1000 * retryCount));
            }
          }
        })());
      }
      
      const sizes = await Promise.all(promises);
      return sizes.reduce((a, b) => a + b, 0);
    };
    
    // Process chunks in parallel batches with dynamic adjustment
    let currentStreamCount = streamCount;
    this.networkMonitor.reset();
    
    for (let batch = 0; batch < totalChunks; batch += currentStreamCount) {
      const batchStart = Date.now();
      const sent = await sendBatch(batch, Math.min(currentStreamCount, totalChunks - batch));
      const batchTime = (Date.now() - batchStart) / 1000;
      
      totalSent += sent;
      transfer.sentChunks = batch + currentStreamCount;
      
      // Update progress
      transfer.progress = (totalSent / fileSize) * 100;
      const elapsed = (Date.now() - startTime) / 1000;
      transfer.speed = totalSent / elapsed;
      
      // Record speed for dynamic adjustment
      this.networkMonitor.recordSpeed(transfer.speed);
      
      // Check if we should adjust stream count
      const adjustment = this.networkMonitor.shouldAdjustStreams(currentStreamCount);
      if (adjustment.adjust && batch < totalChunks - currentStreamCount) {
        console.log(`Adjusting streams: ${currentStreamCount} -> ${adjustment.newCount}`);
        currentStreamCount = adjustment.newCount;
        transfer.streamCount = currentStreamCount;
      }
      
      this.emit('transfer-progress', transfer);
    }
  }
  
  async sendChunkData(socket, data) {
    return this.sendMessage(socket, 5, data);
  }
  
  async waitForChunkAck(socket, chunkIndex, timeout) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        socket.removeListener('data', handler);
        reject(new Error(`Chunk ${chunkIndex} acknowledgment timeout`));
      }, timeout);
      
      const handler = (data) => {
        try {
          if (data.length < 5) return;
          const type = data.readUInt8(4);
          if (type === 6) { // CHUNK_ACK
            const message = JSON.parse(data.slice(5).toString());
            if (message.chunkIndex === chunkIndex) {
              clearTimeout(timer);
              socket.removeListener('data', handler);
              resolve();
            }
          }
        } catch (err) {
          // Ignore parsing errors
        }
      };
      
      socket.on('data', handler);
    });
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
    this.verificationCodes.set(message.deviceId, {
      code,
      socket,
      expiresAt: Date.now() + 300000
    });
    this.emit('verification-required', message.deviceId, code);
    
    // Send verification code back
    this.sendMessage(socket, 1, {
      deviceId: this.deviceManager.getLocalDeviceId(),
      code
    }).catch(err => console.error('Failed to send verification:', err));
  }

  handleVerifyResponse(socket, message) {
    // Handle verification response
    const verification = this.verificationCodes.get(message.deviceId);
    if (verification && verification.code === message.code && message.accepted) {
      this.deviceManager.trustDevice(message.deviceId, message.publicKey);
      this.verificationCodes.delete(message.deviceId);
    }
  }

  async handleTransferRequest(socket, message) {
    // Handle incoming transfer request
    const { transferId, fileName, fileSize, checksum, isDirectory } = message;
    
    // Check available space
    const downloadPath = path.join(
      require('os').homedir(),
      'Downloads',
      fileName
    );
    
    const incomingPath = path.join(this.tempDir, 'incoming', transferId);
    await fs.mkdir(path.dirname(incomingPath), { recursive: true });
    
    // Create incoming transfer object
    const transfer = {
      id: transferId,
      fileName,
      fileSize,
      checksum,
      isDirectory,
      incomingPath,
      downloadPath,
      chunks: [],
      receivedSize: 0,
      status: 'receiving'
    };
    
    this.transfers.set(transferId, transfer);
    
    // Send acceptance
    await this.sendMessage(socket, 4, {
      transferId,
      accepted: true
    });
    
    // Store socket for this transfer
    transfer.socket = socket;
    this.emit('transfer-progress', transfer);
  }

  handleTransferAccept(socket, message) {
    // Handle transfer acceptance - already handled in waitForAcceptance
  }

  async handleChunkData(socket, message) {
    const { transferId, chunkIndex, data, checksum } = message;
    const transfer = this.transfers.get(transferId);
    
    if (!transfer) {
      console.error('Transfer not found:', transferId);
      return;
    }
    
    try {
      // Decode chunk data
      const chunkBuffer = Buffer.from(data, 'base64');
      
      // Verify chunk checksum
      const calculatedChecksum = crypto.createHash('sha256')
        .update(chunkBuffer)
        .digest('hex');
      
      if (calculatedChecksum !== checksum) {
        throw new Error(`Chunk ${chunkIndex} checksum mismatch`);
      }
      
      // Write chunk to file
      const chunkPath = `${transfer.incomingPath}.chunk${chunkIndex}`;
      await fs.writeFile(chunkPath, chunkBuffer);
      
      transfer.chunks[chunkIndex] = {
        path: chunkPath,
        size: chunkBuffer.length,
        received: true
      };
      
      transfer.receivedSize += chunkBuffer.length;
      transfer.progress = (transfer.receivedSize / transfer.fileSize) * 100;
      
      this.emit('transfer-progress', transfer);
      
      // Send acknowledgment
      await this.sendMessage(socket, 6, {
        transferId,
        chunkIndex,
        success: true
      });
      
      // Check if all chunks received
      if (transfer.receivedSize >= transfer.fileSize) {
        await this.finalizeReceivedTransfer(transfer);
      }
      
    } catch (err) {
      console.error('Error handling chunk:', err);
      // Send error acknowledgment
      await this.sendMessage(socket, 6, {
        transferId,
        chunkIndex,
        success: false,
        error: err.message
      });
    }
  }

  handleChunkAck(socket, message) {
    // Acknowledgment already handled in waitForChunkAck
  }
  
  async finalizeReceivedTransfer(transfer) {
    try {
      // Merge all chunks into final file
      const finalPath = transfer.incomingPath;
      const writeStream = require('fs').createWriteStream(finalPath);
      
      for (let i = 0; i < transfer.chunks.length; i++) {
        const chunk = transfer.chunks[i];
        if (chunk && chunk.received) {
          const chunkData = await fs.readFile(chunk.path);
          writeStream.write(chunkData);
          // Delete chunk file
          await fs.unlink(chunk.path).catch(() => {});
        }
      }
      
      await new Promise((resolve, reject) => {
        writeStream.end((err) => {
          if (err) reject(err);
          else resolve();
        });
      });
      
      // Verify full file checksum
      const finalChecksum = await this.calculateChecksum(finalPath);
      if (finalChecksum !== transfer.checksum) {
        throw new Error('File checksum verification failed');
      }
      
      // Decompress if directory
      if (transfer.isDirectory) {
        const extractPath = transfer.downloadPath.replace(/\.tar\.gz$/, '');
        await tar.extract({
          file: finalPath,
          cwd: path.dirname(extractPath)
        });
        await fs.unlink(finalPath);
        transfer.finalPath = extractPath;
      } else {
        // Move to Downloads
        await fs.rename(finalPath, transfer.downloadPath);
        transfer.finalPath = transfer.downloadPath;
      }
      
      transfer.status = 'completed';
      transfer.progress = 100;
      this.emit('transfer-complete', transfer);
      
    } catch (err) {
      transfer.status = 'failed';
      transfer.error = err.message;
      this.emit('transfer-error', transfer, err);
    }
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
