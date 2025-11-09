// Renderer process
let devices = new Map();
let selectedDevices = new Set();
let transfers = new Map();
let currentVerificationDevice = null;

// Initialize
window.addEventListener('DOMContentLoaded', async () => {
  await loadDeviceName();
  await loadSettings();
  setupEventListeners();
  setupIpcListeners();
  await refreshDevices();
  await refreshTransfers();
});

async function loadDeviceName() {
  const name = await window.api.getDeviceName();
  document.getElementById('deviceName').textContent = name;
}

async function loadSettings() {
  const settings = await window.api.getSettings();
  // Settings are loaded, can be used for UI
}

function setupEventListeners() {
  // Drop zone
  const dropZone = document.getElementById('dropZone');
  
  dropZone.addEventListener('click', () => {
    if (selectedDevices.size === 0) {
      alert('Please select at least one device first');
      return;
    }
    selectFiles();
  });

  dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('drag-over');
  });

  dropZone.addEventListener('dragleave', () => {
    dropZone.classList.remove('drag-over');
  });

  dropZone.addEventListener('drop', async (e) => {
    e.preventDefault();
    dropZone.classList.remove('drag-over');

    if (selectedDevices.size === 0) {
      alert('Please select at least one device first');
      return;
    }

    const files = Array.from(e.dataTransfer.files);
    const filePaths = files.map(f => f.path);
    await sendFiles(filePaths);
  });

  // Settings button
  document.getElementById('settingsBtn').addEventListener('click', openSettings);

  // Verification modal
  document.getElementById('verifyAccept').addEventListener('click', () => {
    acceptVerification(true);
  });

  document.getElementById('verifyReject').addEventListener('click', () => {
    acceptVerification(false);
  });

  // Settings modal
  document.getElementById('settingsSave').addEventListener('click', saveSettings);
  document.getElementById('settingsCancel').addEventListener('click', closeSettings);
}

function setupIpcListeners() {
  window.api.onDeviceFound((device) => {
    devices.set(device.id, device);
    renderDevices();
  });

  window.api.onDeviceLost((deviceId) => {
    devices.delete(deviceId);
    selectedDevices.delete(deviceId);
    renderDevices();
  });

  window.api.onTransferProgress((transfer) => {
    transfers.set(transfer.id, transfer);
    renderTransfers();
  });

  window.api.onTransferComplete((transfer) => {
    transfers.set(transfer.id, transfer);
    renderTransfers();
    showNotification('Transfer Complete', `${transfer.filePath} sent successfully`);
  });

  window.api.onTransferError((transfer, error) => {
    transfers.set(transfer.id, transfer);
    renderTransfers();
    showNotification('Transfer Failed', error.message || 'Unknown error');
  });

  window.api.onVerificationRequired((deviceId, code) => {
    showVerificationModal(deviceId, code);
  });
}

async function refreshDevices() {
  const deviceList = await window.api.getDevices();
  devices.clear();
  deviceList.forEach(d => devices.set(d.id, d));
  renderDevices();
}

async function refreshTransfers() {
  const transferList = await window.api.getTransfers();
  transfers.clear();
  transferList.forEach(t => transfers.set(t.id, t));
  renderTransfers();
}

function renderDevices() {
  const devicesList = document.getElementById('devicesList');
  
  if (devices.size === 0) {
    devicesList.innerHTML = `
      <div class="empty-state">
        <svg width="64" height="64" viewBox="0 0 64 64">
          <circle cx="32" cy="32" r="30" fill="#f0f0f0"/>
          <path d="M32 20 L32 44 M20 32 L44 32" stroke="#999" stroke-width="3"/>
        </svg>
        <p>No devices found</p>
        <p class="hint">Devices on the same network will appear here</p>
      </div>
    `;
    return;
  }

  devicesList.innerHTML = Array.from(devices.values())
    .map(device => `
      <div class="device-card ${selectedDevices.has(device.id) ? 'selected' : ''}" 
           data-device-id="${device.id}">
        <div class="device-info">
          <div class="device-name-text">${device.alias || device.name}</div>
          <div class="device-details">
            ${device.platform} • ${device.trusted ? '🔒 Trusted' : 'Not verified'}
          </div>
        </div>
      </div>
    `)
    .join('');

  // Add click handlers
  devicesList.querySelectorAll('.device-card').forEach(card => {
    card.addEventListener('click', () => {
      const deviceId = card.dataset.deviceId;
      if (selectedDevices.has(deviceId)) {
        selectedDevices.delete(deviceId);
        card.classList.remove('selected');
      } else {
        selectedDevices.add(deviceId);
        card.classList.add('selected');
      }
    });
  });
}

function renderTransfers() {
  const transfersList = document.getElementById('transfersList');
  
  if (transfers.size === 0) {
    transfersList.innerHTML = `
      <div class="empty-state">
        <p>No active transfers</p>
      </div>
    `;
    updateQueueStats();
    return;
  }

  transfersList.innerHTML = Array.from(transfers.values())
    .map(transfer => `
      <div class="transfer-item">
        <div class="transfer-header">
          <div class="transfer-filename">${getFileName(transfer.filePath)}</div>
          <div class="transfer-actions">
            ${transfer.status === 'transferring' ? '<button onclick="pauseTransfer(\'' + transfer.id + '\')">⏸</button>' : ''}
            ${transfer.status === 'paused' ? '<button onclick="resumeTransfer(\'' + transfer.id + '\')">▶</button>' : ''}
            <button onclick="cancelTransfer('${transfer.id}')">✕</button>
          </div>
        </div>
        <div class="transfer-progress">
          <div class="progress-bar">
            <div class="progress-fill ${getProgressClass(transfer.status)}" 
                 style="width: ${transfer.progress || 0}%"></div>
          </div>
        </div>
        <div class="transfer-stats">
          <span>${transfer.status}</span>
          <span>${transfer.progress || 0}%</span>
        </div>
      </div>
    `)
    .join('');

  updateQueueStats();
}

function getFileName(filePath) {
  return filePath.split('/').pop().split('\\').pop();
}

function getProgressClass(status) {
  if (status === 'completed') return 'success';
  if (status === 'failed') return 'error';
  return '';
}

function updateQueueStats() {
  const stats = document.getElementById('queueStats');
  const total = transfers.size;
  const completed = Array.from(transfers.values()).filter(t => t.status === 'completed').length;
  
  if (total > 0) {
    stats.textContent = `${completed} / ${total}`;
  } else {
    stats.textContent = '';
  }
}

function selectFiles() {
  const input = document.createElement('input');
  input.type = 'file';
  input.multiple = true;
  input.onchange = async (e) => {
    const files = Array.from(e.target.files);
    const filePaths = files.map(f => f.path);
    await sendFiles(filePaths);
  };
  input.click();
}

async function sendFiles(filePaths) {
  const deviceIds = Array.from(selectedDevices);
  await window.api.sendFiles(deviceIds, filePaths);
  await refreshTransfers();
}

window.pauseTransfer = async function(transferId) {
  await window.api.pauseTransfer(transferId);
  await refreshTransfers();
}

window.resumeTransfer = async function(transferId) {
  await window.api.resumeTransfer(transferId);
  await refreshTransfers();
}

window.cancelTransfer = async function(transferId) {
  if (confirm('Are you sure you want to cancel this transfer?')) {
    await window.api.cancelTransfer(transferId);
    await refreshTransfers();
  }
}

function showVerificationModal(deviceId, code) {
  currentVerificationDevice = deviceId;
  document.getElementById('verificationCode').textContent = code;
  document.getElementById('verificationModal').classList.remove('hidden');
}

async function acceptVerification(accept) {
  if (currentVerificationDevice) {
    await window.api.verifyDevice(currentVerificationDevice, accept);
    currentVerificationDevice = null;
  }
  document.getElementById('verificationModal').classList.add('hidden');
  await refreshDevices();
}

async function openSettings() {
  const settings = await window.api.getSettings();
  const deviceName = await window.api.getDeviceName();
  
  document.getElementById('deviceNameInput').value = deviceName;
  document.getElementById('streamCountSelect').value = settings.streamCount;
  document.getElementById('languageSelect').value = settings.language;
  document.getElementById('notificationsCheck').checked = settings.notifications;
  document.getElementById('notificationSoundCheck').checked = settings.notificationSound;
  document.getElementById('autoAcceptCheck').checked = settings.autoAcceptTrusted;
  document.getElementById('themeSelect').value = settings.theme;
  
  document.getElementById('settingsModal').classList.remove('hidden');
}

function closeSettings() {
  document.getElementById('settingsModal').classList.add('hidden');
}

async function saveSettings() {
  const deviceName = document.getElementById('deviceNameInput').value;
  const settings = {
    streamCount: document.getElementById('streamCountSelect').value,
    language: document.getElementById('languageSelect').value,
    notifications: document.getElementById('notificationsCheck').checked,
    notificationSound: document.getElementById('notificationSoundCheck').checked,
    autoAcceptTrusted: document.getElementById('autoAcceptCheck').checked,
    theme: document.getElementById('themeSelect').value
  };
  
  await window.api.setDeviceName(deviceName);
  await window.api.updateSettings(settings);
  await loadDeviceName();
  
  closeSettings();
}

function showNotification(title, body) {
  if (Notification.permission === 'granted') {
    new Notification(title, { body });
  }
}

// Request notification permission
if (Notification.permission === 'default') {
  Notification.requestPermission();
}
