const forge = require('node-forge');
const fs = require('fs').promises;
const path = require('path');
const os = require('os');

/**
 * Certificate Manager with Trust-On-First-Use (TOFU) pinning
 * Stores trusted device certificates after first successful connection
 */
class CertificateManager {
  constructor() {
    this.configDir = path.join(os.homedir(), '.rapidtransfer');
    this.certsDir = path.join(this.configDir, 'certs');
    this.pinnedCertsFile = path.join(this.configDir, 'pinned_certs.json');
    this.pinnedCerts = new Map();
    this.localCert = null;
    this.localKey = null;
  }

  /**
   * Initialize certificate manager and load pinned certificates
   */
  async initialize() {
    try {
      // Create directories if they don't exist
      await fs.mkdir(this.certsDir, { recursive: true });
      
      // Load pinned certificates
      await this.loadPinnedCertificates();
      
      // Load or generate local certificate
      await this.loadOrGenerateLocalCertificate();
      
      console.log('Certificate manager initialized');
    } catch (error) {
      console.error('Failed to initialize certificate manager:', error);
      throw error;
    }
  }

  /**
   * Load pinned certificates from disk
   */
  async loadPinnedCertificates() {
    try {
      const data = await fs.readFile(this.pinnedCertsFile, 'utf8');
      const pinnedData = JSON.parse(data);
      
      for (const [deviceId, certData] of Object.entries(pinnedData)) {
        this.pinnedCerts.set(deviceId, {
          fingerprint: certData.fingerprint,
          pinnedAt: new Date(certData.pinnedAt),
          deviceName: certData.deviceName,
          publicKey: certData.publicKey,
        });
      }
      
      console.log(`Loaded ${this.pinnedCerts.size} pinned certificates`);
    } catch (error) {
      if (error.code !== 'ENOENT') {
        console.error('Error loading pinned certificates:', error);
      }
      // File doesn't exist yet, that's okay
    }
  }

  /**
   * Save pinned certificates to disk
   */
  async savePinnedCertificates() {
    try {
      const pinnedData = {};
      
      for (const [deviceId, certData] of this.pinnedCerts.entries()) {
        pinnedData[deviceId] = {
          fingerprint: certData.fingerprint,
          pinnedAt: certData.pinnedAt.toISOString(),
          deviceName: certData.deviceName,
          publicKey: certData.publicKey,
        };
      }
      
      await fs.writeFile(
        this.pinnedCertsFile,
        JSON.stringify(pinnedData, null, 2),
        'utf8'
      );
    } catch (error) {
      console.error('Error saving pinned certificates:', error);
    }
  }

  /**
   * Load or generate local certificate and private key
   */
  async loadOrGenerateLocalCertificate() {
    const certPath = path.join(this.certsDir, 'local_cert.pem');
    const keyPath = path.join(this.certsDir, 'local_key.pem');
    
    try {
      // Try to load existing certificate
      const certPem = await fs.readFile(certPath, 'utf8');
      const keyPem = await fs.readFile(keyPath, 'utf8');
      
      this.localCert = forge.pki.certificateFromPem(certPem);
      this.localKey = forge.pki.privateKeyFromPem(keyPem);
      
      console.log('Loaded existing local certificate');
    } catch (error) {
      // Generate new certificate
      console.log('Generating new local certificate...');
      
      const keys = forge.pki.rsa.generateKeyPair(2048);
      const cert = forge.pki.createCertificate();
      
      cert.publicKey = keys.publicKey;
      cert.serialNumber = '01';
      cert.validity.notBefore = new Date();
      cert.validity.notAfter = new Date();
      cert.validity.notAfter.setFullYear(cert.validity.notBefore.getFullYear() + 10);
      
      const attrs = [{
        name: 'commonName',
        value: 'Rapid Transfer Device'
      }, {
        name: 'countryName',
        value: 'US'
      }, {
        shortName: 'OU',
        value: 'Rapid Transfer'
      }];
      
      cert.setSubject(attrs);
      cert.setIssuer(attrs);
      cert.sign(keys.privateKey, forge.md.sha256.create());
      
      // Save certificate and key
      const certPem = forge.pki.certificateToPem(cert);
      const keyPem = forge.pki.privateKeyToPem(keys.privateKey);
      
      await fs.writeFile(certPath, certPem, 'utf8');
      await fs.writeFile(keyPath, keyPem, 'utf8');
      
      this.localCert = cert;
      this.localKey = keys.privateKey;
      
      console.log('Generated and saved new local certificate');
    }
  }

  /**
   * Get local certificate and private key for TLS
   */
  getLocalCredentials() {
    return {
      cert: forge.pki.certificateToPem(this.localCert),
      key: forge.pki.privateKeyToPem(this.localKey),
    };
  }

  /**
   * Calculate certificate fingerprint (SHA-256)
   */
  calculateFingerprint(cert) {
    const certDer = forge.asn1.toDer(forge.pki.certificateToAsn1(cert)).getBytes();
    const md = forge.md.sha256.create();
    md.update(certDer);
    return md.digest().toHex();
  }

  /**
   * Pin a certificate for a device (Trust-On-First-Use)
   */
  async pinCertificate(deviceId, deviceName, cert) {
    const fingerprint = this.calculateFingerprint(cert);
    const publicKey = forge.pki.publicKeyToPem(cert.publicKey);
    
    this.pinnedCerts.set(deviceId, {
      fingerprint,
      pinnedAt: new Date(),
      deviceName,
      publicKey,
    });
    
    await this.savePinnedCertificates();
    
    console.log(`Pinned certificate for device ${deviceName} (${deviceId})`);
  }

  /**
   * Verify a certificate against pinned certificate
   */
  verifyCertificate(deviceId, cert) {
    const pinnedData = this.pinnedCerts.get(deviceId);
    
    if (!pinnedData) {
      // First connection - not pinned yet
      return { verified: false, reason: 'not_pinned', requiresPinning: true };
    }
    
    const fingerprint = this.calculateFingerprint(cert);
    
    if (fingerprint !== pinnedData.fingerprint) {
      // Certificate changed - possible MITM attack
      console.warn(`Certificate mismatch for device ${deviceId}!`);
      return { verified: false, reason: 'fingerprint_mismatch', requiresPinning: false };
    }
    
    // Certificate matches pinned version
    return { verified: true, reason: 'pinned', requiresPinning: false };
  }

  /**
   * Check if device certificate is pinned
   */
  isPinned(deviceId) {
    return this.pinnedCerts.has(deviceId);
  }

  /**
   * Get pinned certificate data for device
   */
  getPinnedCertificate(deviceId) {
    return this.pinnedCerts.get(deviceId);
  }

  /**
   * Unpin (forget) a device certificate
   */
  async unpinCertificate(deviceId) {
    this.pinnedCerts.delete(deviceId);
    await this.savePinnedCertificates();
    console.log(`Unpinned certificate for device ${deviceId}`);
  }

  /**
   * Get all pinned devices
   */
  getAllPinnedDevices() {
    const devices = [];
    for (const [deviceId, data] of this.pinnedCerts.entries()) {
      devices.push({
        deviceId,
        deviceName: data.deviceName,
        pinnedAt: data.pinnedAt,
        fingerprint: data.fingerprint,
      });
    }
    return devices;
  }

  /**
   * Update device name for pinned certificate
   */
  async updateDeviceName(deviceId, newName) {
    const pinnedData = this.pinnedCerts.get(deviceId);
    if (pinnedData) {
      pinnedData.deviceName = newName;
      await this.savePinnedCertificates();
    }
  }
}

module.exports = CertificateManager;
