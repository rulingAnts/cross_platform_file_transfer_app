/**
 * Rapid Transfer - Discovery Service (UDP Broadcast)
 * Copyright (C) 2025 Seth Johnston - Licensed under AGPL-3.0
 */

const dgram = require('dgram');
const os = require('os');

const DISCOVERY_PORT = 8766;
const BROADCAST_INTERVAL = 5000; // 5 seconds
const DEVICE_TIMEOUT = 30000; // 30 seconds

class DiscoveryService {
  constructor(deviceManager) {
    this.deviceManager = deviceManager;
    this.socket = null;
    this.broadcastInterval = null;
    this.cleanupInterval = null;
    this.discoveredDevices = new Map(); // Track last seen times
  }

  async start() {
    try {
      // Create UDP socket
      this.socket = dgram.createSocket({ type: 'udp4', reuseAddr: true });

      // Enable broadcast
      this.socket.on('listening', () => {
        this.socket.setBroadcast(true);
        const address = this.socket.address();
        console.log(`UDP Discovery listening on ${address.address}:${address.port}`);
      });

      // Handle incoming messages
      this.socket.on('message', (msg, rinfo) => {
        this.handleMessage(msg, rinfo);
      });

      this.socket.on('error', (err) => {
        console.error('UDP socket error:', err);
      });

      // Bind to discovery port
      await new Promise((resolve, reject) => {
        this.socket.bind(DISCOVERY_PORT, () => {
          resolve();
        });
        this.socket.once('error', reject);
      });

      // Start broadcasting our presence
      this.startBroadcasting();

      // Start cleanup interval
      this.cleanupInterval = setInterval(() => {
        this.cleanupStaleDevices();
      }, 10000); // Check every 10 seconds

      console.log('UDP Discovery service started');

    } catch (err) {
      console.error('Failed to start discovery service:', err);
      throw err;
    }
  }

  startBroadcasting() {
    const broadcast = () => {
      const message = this.createBroadcastMessage();
      const broadcastAddresses = this.getBroadcastAddresses();

      broadcastAddresses.forEach(address => {
        this.socket.send(message, 0, message.length, DISCOVERY_PORT, address, (err) => {
          if (err) {
            console.error(`Failed to send broadcast to ${address}:`, err);
          }
        });
      });
    };

    // Broadcast immediately and then periodically
    broadcast();
    this.broadcastInterval = setInterval(broadcast, BROADCAST_INTERVAL);
  }

  createBroadcastMessage() {
    const deviceInfo = {
      id: this.deviceManager.getLocalDeviceId(),
      name: this.deviceManager.getLocalDeviceName(),
      platform: os.platform(),
      version: '0.1.0',
      port: 8765
    };
    return Buffer.from(JSON.stringify(deviceInfo));
  }

  getBroadcastAddresses() {
    const addresses = [];
    const interfaces = os.networkInterfaces();

    for (const iface of Object.values(interfaces)) {
      for (const config of iface) {
        // Only IPv4 and not internal
        if (config.family === 'IPv4' && !config.internal) {
          // Calculate broadcast address
          const broadcast = this.calculateBroadcastAddress(config.address, config.netmask);
          if (broadcast && !addresses.includes(broadcast)) {
            addresses.push(broadcast);
          }
        }
      }
    }

    // Fallback to global broadcast if no specific addresses found
    if (addresses.length === 0) {
      addresses.push('255.255.255.255');
    }

    return addresses;
  }

  calculateBroadcastAddress(ip, netmask) {
    try {
      const ipParts = ip.split('.').map(Number);
      const maskParts = netmask.split('.').map(Number);
      
      const broadcast = ipParts.map((part, i) => {
        return part | (~maskParts[i] & 255);
      });
      
      return broadcast.join('.');
    } catch (err) {
      console.error('Failed to calculate broadcast address:', err);
      return null;
    }
  }

  handleMessage(msg, rinfo) {
    try {
      const data = JSON.parse(msg.toString());
      
      // Validate message format
      if (!data.id || !data.name || !data.port) {
        return;
      }

      // Don't add ourselves
      if (data.id === this.deviceManager.getLocalDeviceId()) {
        return;
      }

      // Update last seen time
      this.discoveredDevices.set(data.id, Date.now());

      // Create device object
      const device = {
        id: data.id,
        name: data.name,
        address: rinfo.address,
        port: data.port,
        platform: data.platform || 'unknown',
        version: data.version || '0.0.0'
      };

      // Add or update device
      this.deviceManager.addDevice(device);

    } catch (err) {
      // Ignore malformed messages
      console.debug('Failed to parse broadcast message:', err.message);
    }
  }

  cleanupStaleDevices() {
    const now = Date.now();
    const staleDevices = [];

    for (const [deviceId, lastSeen] of this.discoveredDevices.entries()) {
      if (now - lastSeen > DEVICE_TIMEOUT) {
        staleDevices.push(deviceId);
      }
    }

    staleDevices.forEach(deviceId => {
      this.discoveredDevices.delete(deviceId);
      this.deviceManager.removeDevice(deviceId);
      console.log('Device timed out:', deviceId);
    });
  }

  updateServiceName(_name) {
    // Name will be updated on next broadcast automatically
    // No action needed - broadcast interval will pick up new name
  }

  stop() {
    if (this.broadcastInterval) {
      clearInterval(this.broadcastInterval);
      this.broadcastInterval = null;
    }

    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }

    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }

    this.discoveredDevices.clear();
    console.log('UDP Discovery service stopped');
  }
}

module.exports = DiscoveryService;
