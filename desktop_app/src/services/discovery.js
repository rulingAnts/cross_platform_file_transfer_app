const Bonjour = require('bonjour-service');
const os = require('os');

class DiscoveryService {
  constructor(deviceManager) {
    this.deviceManager = deviceManager;
    this.bonjour = null;
    this.service = null;
    this.browser = null;
    this.serviceType = 'rapidtransfer';
    this.protocol = 'tcp';
  }

  async start() {
    try {
      this.bonjour = new Bonjour.Bonjour();

      // Publish our service
      this.service = this.bonjour.publish({
        name: this.deviceManager.getLocalDeviceName(),
        type: this.serviceType,
        port: 8765, // Will be replaced by actual transfer service port
        protocol: this.protocol,
        txt: {
          id: this.deviceManager.getLocalDeviceId(),
          version: '0.1.0',
          platform: os.platform()
        }
      });

      this.service.on('up', () => {
        console.log('Service published successfully');
      });

      this.service.on('error', (err) => {
        console.error('Service publication error:', err);
      });

      // Browse for other services
      this.browser = this.bonjour.find({
        type: this.serviceType,
        protocol: this.protocol
      });

      this.browser.on('up', (service) => {
        this.handleServiceUp(service);
      });

      this.browser.on('down', (service) => {
        this.handleServiceDown(service);
      });

      console.log('Discovery service started');

      // Periodically clean up old devices
      this.cleanupInterval = setInterval(() => {
        this.deviceManager.cleanupOldDevices();
      }, 60000); // Every minute

    } catch (err) {
      console.error('Failed to start discovery service:', err);
      throw err;
    }
  }

  handleServiceUp(service) {
    // Don't add ourselves
    if (service.txt?.id === this.deviceManager.getLocalDeviceId()) {
      return;
    }

    const device = {
      id: service.txt?.id || service.fqdn,
      name: service.name,
      address: service.addresses?.[0] || service.host,
      port: service.port,
      platform: service.txt?.platform || 'unknown',
      version: service.txt?.version || '0.0.0'
    };

    console.log('Device discovered:', device);
    this.deviceManager.addDevice(device);
  }

  handleServiceDown(service) {
    const deviceId = service.txt?.id || service.fqdn;
    console.log('Device lost:', deviceId);
    this.deviceManager.removeDevice(deviceId);
  }

  updateServiceName(name) {
    if (this.service) {
      this.service.stop(() => {
        this.service = this.bonjour.publish({
          name: name,
          type: this.serviceType,
          port: 8765,
          protocol: this.protocol,
          txt: {
            id: this.deviceManager.getLocalDeviceId(),
            version: '0.1.0',
            platform: os.platform()
          }
        });
      });
    }
  }

  stop() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }
    if (this.browser) {
      this.browser.stop();
    }
    if (this.service) {
      this.service.stop();
    }
    if (this.bonjour) {
      this.bonjour.destroy();
    }
    console.log('Discovery service stopped');
  }
}

module.exports = DiscoveryService;
