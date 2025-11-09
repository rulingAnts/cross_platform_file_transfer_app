const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('api', {
  // Device management
  getDevices: () => ipcRenderer.invoke('get-devices'),
  setDeviceName: (name) => ipcRenderer.invoke('set-device-name', name),
  getDeviceName: () => ipcRenderer.invoke('get-device-name'),
  forgetDevice: (deviceId) => ipcRenderer.invoke('forget-device', deviceId),
  setDeviceAlias: (deviceId, alias) => ipcRenderer.invoke('set-device-alias', deviceId, alias),

  // File transfer
  sendFiles: (deviceIds, filePaths) => ipcRenderer.invoke('send-files', deviceIds, filePaths),
  getTransfers: () => ipcRenderer.invoke('get-transfers'),
  pauseTransfer: (transferId) => ipcRenderer.invoke('pause-transfer', transferId),
  resumeTransfer: (transferId) => ipcRenderer.invoke('resume-transfer', transferId),
  cancelTransfer: (transferId) => ipcRenderer.invoke('cancel-transfer', transferId),
  verifyDevice: (deviceId, accept) => ipcRenderer.invoke('verify-device', deviceId, accept),

  // Settings
  getSettings: () => ipcRenderer.invoke('get-settings'),
  updateSettings: (settings) => ipcRenderer.invoke('update-settings', settings),

  // Event listeners
  onDeviceFound: (callback) => {
    ipcRenderer.on('device-found', (event, device) => callback(device));
  },
  onDeviceLost: (callback) => {
    ipcRenderer.on('device-lost', (event, deviceId) => callback(deviceId));
  },
  onTransferProgress: (callback) => {
    ipcRenderer.on('transfer-progress', (event, transfer) => callback(transfer));
  },
  onTransferComplete: (callback) => {
    ipcRenderer.on('transfer-complete', (event, transfer) => callback(transfer));
  },
  onTransferError: (callback) => {
    ipcRenderer.on('transfer-error', (event, transfer, error) => callback(transfer, error));
  },
  onVerificationRequired: (callback) => {
    ipcRenderer.on('verification-required', (event, deviceId, code) => callback(deviceId, code));
  }
});
