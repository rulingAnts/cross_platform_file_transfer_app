class NetworkMonitor {
  constructor() {
    this.speedHistory = [];
    this.maxHistorySize = 10;
    this.targetSpeed = 10 * 1024 * 1024; // 10 Mbps
  }

  recordSpeed(bytesPerSecond) {
    this.speedHistory.push({
      speed: bytesPerSecond,
      timestamp: Date.now()
    });

    // Keep only recent history
    if (this.speedHistory.length > this.maxHistorySize) {
      this.speedHistory.shift();
    }
  }

  getAverageSpeed() {
    if (this.speedHistory.length === 0) return 0;

    const sum = this.speedHistory.reduce((acc, entry) => acc + entry.speed, 0);
    return sum / this.speedHistory.length;
  }

  shouldAdjustStreams(currentStreams) {
    if (this.speedHistory.length < 3) {
      return { adjust: false, newCount: currentStreams };
    }

    const avgSpeed = this.getAverageSpeed();
    const recentSpeed = this.speedHistory.slice(-3).reduce((acc, e) => acc + e.speed, 0) / 3;

    // Speed is plateauing and below target
    if (recentSpeed < this.targetSpeed && currentStreams < 8) {
      // Check if speed is stable (not increasing)
      const speedChange = Math.abs(recentSpeed - avgSpeed) / avgSpeed;
      
      if (speedChange < 0.1) { // Less than 10% variation
        return { adjust: true, newCount: Math.min(currentStreams + 1, 8) };
      }
    }

    // Speed is good, consider reducing streams if excessive
    if (recentSpeed > this.targetSpeed * 1.5 && currentStreams > 1) {
      return { adjust: true, newCount: Math.max(currentStreams - 1, 1) };
    }

    return { adjust: false, newCount: currentStreams };
  }

  reset() {
    this.speedHistory = [];
  }
}

module.exports = NetworkMonitor;
