class TransferHistory {
  final String id;
  final String fileName;
  final int fileSize;
  final String deviceId;
  final String deviceName;
  final TransferDirection direction;
  final DateTime completedAt;
  final Duration duration;
  final int bytesTransferred;
  final double averageSpeed; // bytes per second
  final bool successful;
  final String? errorMessage;

  TransferHistory({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.deviceId,
    required this.deviceName,
    required this.direction,
    required this.completedAt,
    required this.duration,
    required this.bytesTransferred,
    required this.averageSpeed,
    this.successful = true,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileSize': fileSize,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'direction': direction == TransferDirection.sending ? 'sending' : 'receiving',
      'completedAt': completedAt.toIso8601String(),
      'duration': duration.inSeconds,
      'bytesTransferred': bytesTransferred,
      'averageSpeed': averageSpeed,
      'successful': successful,
      'errorMessage': errorMessage,
    };
  }

  factory TransferHistory.fromJson(Map<String, dynamic> json) {
    return TransferHistory(
      id: json['id'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      direction: json['direction'] == 'sending' 
          ? TransferDirection.sending 
          : TransferDirection.receiving,
      completedAt: DateTime.parse(json['completedAt']),
      duration: Duration(seconds: json['duration']),
      bytesTransferred: json['bytesTransferred'],
      averageSpeed: json['averageSpeed'],
      successful: json['successful'] ?? true,
      errorMessage: json['errorMessage'],
    );
  }

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedSpeed {
    if (averageSpeed < 1024) return '${averageSpeed.toStringAsFixed(0)} B/s';
    if (averageSpeed < 1024 * 1024) {
      return '${(averageSpeed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(averageSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedDuration {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }
}

enum TransferDirection {
  sending,
  receiving,
}
