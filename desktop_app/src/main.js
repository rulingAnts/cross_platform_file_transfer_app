const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const DiscoveryService = require('./services/discovery');
const TransferService = require('./services/transfer');
const DeviceManager = require('./services/deviceManager');

let mainWindow;
let discoveryService;
let transferService;
let deviceManager;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    icon: path.join(__dirname, '../build/icon.png')
  });

  mainWindow.loadFile(path.join(__dirname, 'ui', 'index.html'));

  // Open DevTools in development
  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

function initializeServices() {
  deviceManager = new DeviceManager();
  discoveryService = new DiscoveryService(deviceManager);
  transferService = new TransferService(deviceManager);

  // Set up IPC handlers
  setupIpcHandlers();

  // Start discovery
  discoveryService.start().catch(err => {
    console.error('Failed to start discovery service:', err);
  });

  // Start transfer service
  transferService.start().catch(err => {
    console.error('Failed to start transfer service:', err);
  });
}

function setupIpcHandlers() {
  // Device management
  ipcMain.handle('get-devices', async () => {
    return deviceManager.getDevices();
  });

  ipcMain.handle('set-device-name', async (event, name) => {
    return deviceManager.setLocalDeviceName(name);
  });

  ipcMain.handle('get-device-name', async () => {
    return deviceManager.getLocalDeviceName();
  });

  ipcMain.handle('forget-device', async (event, deviceId) => {
    return deviceManager.forgetDevice(deviceId);
  });

  ipcMain.handle('set-device-alias', async (event, deviceId, alias) => {
    return deviceManager.setDeviceAlias(deviceId, alias);
  });

  // File transfer
  ipcMain.handle('send-files', async (event, deviceIds, filePaths) => {
    return transferService.sendFiles(deviceIds, filePaths);
  });

  ipcMain.handle('get-transfers', async () => {
    return transferService.getTransfers();
  });

  ipcMain.handle('pause-transfer', async (event, transferId) => {
    return transferService.pauseTransfer(transferId);
  });

  ipcMain.handle('resume-transfer', async (event, transferId) => {
    return transferService.resumeTransfer(transferId);
  });

  ipcMain.handle('cancel-transfer', async (event, transferId) => {
    return transferService.cancelTransfer(transferId);
  });

  // Settings
  ipcMain.handle('get-settings', async () => {
    return deviceManager.getSettings();
  });

  ipcMain.handle('update-settings', async (event, settings) => {
    return deviceManager.updateSettings(settings);
  });

  // Forward events to renderer
  deviceManager.on('device-found', (device) => {
    if (mainWindow) {
      mainWindow.webContents.send('device-found', device);
    }
  });

  deviceManager.on('device-lost', (deviceId) => {
    if (mainWindow) {
      mainWindow.webContents.send('device-lost', deviceId);
    }
  });

  transferService.on('transfer-progress', (transfer) => {
    if (mainWindow) {
      mainWindow.webContents.send('transfer-progress', transfer);
    }
  });

  transferService.on('transfer-complete', (transfer) => {
    if (mainWindow) {
      mainWindow.webContents.send('transfer-complete', transfer);
    }
  });

  transferService.on('transfer-error', (transfer, error) => {
    if (mainWindow) {
      mainWindow.webContents.send('transfer-error', transfer, error);
    }
  });

  transferService.on('verification-required', (deviceId, code) => {
    if (mainWindow) {
      mainWindow.webContents.send('verification-required', deviceId, code);
    }
  });

  ipcMain.handle('verify-device', async (event, deviceId, accept) => {
    return transferService.verifyDevice(deviceId, accept);
  });
}

app.whenReady().then(() => {
  createWindow();
  initializeServices();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (discoveryService) {
    discoveryService.stop();
  }
  if (transferService) {
    transferService.stop();
  }
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('before-quit', () => {
  if (discoveryService) {
    discoveryService.stop();
  }
  if (transferService) {
    transferService.stop();
  }
});
