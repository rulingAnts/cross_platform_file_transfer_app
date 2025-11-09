enum TransferStatus {
  pending,
  preparing,
  compressing,
  checksumming,
  connecting,
  transferring,
  paused,
  completed,
  failed,
  cancelled,
}

class FileTransfer {
  final String id;
  final String deviceId;
  final String filePath;
  final String fileName;
  final int size;
  final bool isDirectory;
  final TransferStatus status;
  final double progress;
  final String? error;
  final String? checksum;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int? bytesTransferred;
  final double? speed; // bytes per second

  FileTransfer({
    required this.id,
    required this.deviceId,
    required this.filePath,
    required this.fileName,
    required this.size,
    this.isDirectory = false,
    this.status = TransferStatus.pending,
    this.progress = 0,
    this.error,
    this.checksum,
    DateTime? createdAt,
    this.completedAt,
    this.bytesTransferred,
    this.speed,
  }) : createdAt = createdAt ?? DateTime.now();

  FileTransfer copyWith({
    TransferStatus? status,
    double? progress,
    String? error,
    String? checksum,
    DateTime? completedAt,
    int? bytesTransferred,
    double? speed,
  }) {
    return FileTransfer(
      id: id,
      deviceId: deviceId,
      filePath: filePath,
      fileName: fileName,
      size: size,
      isDirectory: isDirectory,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      checksum: checksum ?? this.checksum,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      speed: speed ?? this.speed,
    );
  }

  String get statusText {
    switch (status) {
      case TransferStatus.pending:
        return 'Pending';
      case TransferStatus.preparing:
        return 'Preparing';
      case TransferStatus.compressing:
        return 'Compressing';
      case TransferStatus.checksumming:
        return 'Verifying';
      case TransferStatus.connecting:
        return 'Connecting';
      case TransferStatus.transferring:
        return 'Transferring';
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.cancelled:
        return 'Cancelled';
    }
  }

  String formatSize() {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String formatSpeed() {
    if (speed == null) return '';
    if (speed! < 1024) return '${speed!.toStringAsFixed(0)} B/s';
    if (speed! < 1024 * 1024) {
      return '${(speed! / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speed! / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Duration? get estimatedTimeRemaining {
    if (speed == null || speed! == 0 || bytesTransferred == null) {
      return null;
    }
    final remaining = size - bytesTransferred!;
    final seconds = remaining / speed!;
    return Duration(seconds: seconds.toInt());
  }
}
