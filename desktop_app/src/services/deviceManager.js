const EventEmitter = require('events');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const CertificateManager = require('./certificateManager');

class DeviceManager extends EventEmitter {
  constructor() {
    super();
    this.devices = new Map();
    this.localDeviceId = this.generateDeviceId();
    this.localDeviceName = os.hostname();
    this.trustedDevices = new Map();
    this.deviceAliases = new Map();
    this.certificateManager = new CertificateManager();
    this.settings = {
      streamCount: 'auto',
      language: 'en',
      notifications: true,
      notificationSound: true,
      autoAcceptTrusted: true,
      theme: 'auto',
      downloadPath: path.join(os.homedir(), 'Downloads')
    };
    this.configPath = path.join(os.homedir(), '.rapidtransfer');
    this.init();
  }

  async init() {
    try {
      await fs.mkdir(this.configPath, { recursive: true });
      await this.certificateManager.initialize();
      await this.loadConfig();
    } catch (err) {
      console.error('Failed to initialize device manager:', err);
    }
  }

  generateDeviceId() {
    return crypto.randomBytes(16).toString('hex');
  }

  async loadConfig() {
    try {
      const configFile = path.join(this.configPath, 'config.json');
      const data = await fs.readFile(configFile, 'utf-8');
      const config = JSON.parse(data);
      
      this.localDeviceId = config.deviceId || this.localDeviceId;
      this.localDeviceName = config.deviceName || this.localDeviceName;
      this.trustedDevices = new Map(Object.entries(config.trustedDevices || {}));
      this.deviceAliases = new Map(Object.entries(config.deviceAliases || {}));
      this.settings = { ...this.settings, ...config.settings };
    } catch (err) {
      if (err.code !== 'ENOENT') {
        console.error('Failed to load config:', err);
      }
      await this.saveConfig();
    }
  }

  async saveConfig() {
    try {
      const configFile = path.join(this.configPath, 'config.json');
      const config = {
        deviceId: this.localDeviceId,
        deviceName: this.localDeviceName,
        trustedDevices: Object.fromEntries(this.trustedDevices),
        deviceAliases: Object.fromEntries(this.deviceAliases),
        settings: this.settings
      };
      await fs.writeFile(configFile, JSON.stringify(config, null, 2));
    } catch (err) {
      console.error('Failed to save config:', err);
    }
  }

  getLocalDeviceId() {
    return this.localDeviceId;
  }

  getLocalDeviceName() {
    return this.localDeviceName;
  }

  async setLocalDeviceName(name) {
    this.localDeviceName = name;
    await this.saveConfig();
    return true;
  }

  addDevice(device) {
    this.devices.set(device.id, {
      ...device,
      lastSeen: Date.now(),
      alias: this.deviceAliases.get(device.id) || null,
      trusted: this.trustedDevices.has(device.id)
    });
    this.emit('device-found', this.devices.get(device.id));
  }

  removeDevice(deviceId) {
    if (this.devices.has(deviceId)) {
      this.devices.delete(deviceId);
      this.emit('device-lost', deviceId);
    }
  }

  getDevice(deviceId) {
    return this.devices.get(deviceId);
  }

  getDevices() {
    return Array.from(this.devices.values());
  }

  async trustDevice(deviceId, publicKey) {
    this.trustedDevices.set(deviceId, {
      publicKey,
      trustedAt: Date.now()
    });
    const device = this.devices.get(deviceId);
    if (device) {
      device.trusted = true;
    }
    await this.saveConfig();
  }

  async forgetDevice(deviceId) {
    this.trustedDevices.delete(deviceId);
    this.deviceAliases.delete(deviceId);
    const device = this.devices.get(deviceId);
    if (device) {
      device.trusted = false;
      device.alias = null;
    }
    await this.saveConfig();
    return true;
  }

  async setDeviceAlias(deviceId, alias) {
    if (alias) {
      this.deviceAliases.set(deviceId, alias);
    } else {
      this.deviceAliases.delete(deviceId);
    }
    const device = this.devices.get(deviceId);
    if (device) {
      device.alias = alias;
    }
    await this.saveConfig();
    return true;
  }

  isTrusted(deviceId) {
    return this.trustedDevices.has(deviceId);
  }

  getTrustedDeviceKey(deviceId) {
    const trusted = this.trustedDevices.get(deviceId);
    return trusted ? trusted.publicKey : null;
  }

  getSettings() {
    return { ...this.settings };
  }

  async updateSettings(newSettings) {
    this.settings = { ...this.settings, ...newSettings };
    await this.saveConfig();
    return true;
  }

  // Clean up old devices that haven't been seen in a while
  cleanupOldDevices(timeoutMs = 300000) { // 5 minutes default
    const now = Date.now();
    for (const [deviceId, device] of this.devices.entries()) {
      if (now - device.lastSeen > timeoutMs) {
        this.removeDevice(deviceId);
      }
    }
  }
}

module.exports = DeviceManager;
