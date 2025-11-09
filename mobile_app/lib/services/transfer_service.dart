import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import 'device_manager.dart';

class TransferService extends ChangeNotifier {
  final DeviceManager deviceManager;
  final Map<String, FileTransfer> _transfers = {};

  TransferService(this.deviceManager);

  List<FileTransfer> get transfers => _transfers.values.toList();
  
  List<FileTransfer> get activeTransfers => _transfers.values
      .where((t) => t.status == TransferStatus.transferring ||
                    t.status == TransferStatus.preparing ||
                    t.status == TransferStatus.connecting)
      .toList();

  Future<void> init() async {
    // TODO: Start transfer service
  }

  Future<void> sendFiles(List<String> deviceIds, List<String> filePaths) async {
    for (final deviceId in deviceIds) {
      for (final filePath in filePaths) {
        final transferId = '${DateTime.now().millisecondsSinceEpoch}_${filePath.hashCode}';
        final fileName = filePath.split('/').last;
        
        final transfer = FileTransfer(
          id: transferId,
          deviceId: deviceId,
          filePath: filePath,
          fileName: fileName,
          size: 0, // TODO: Get actual file size
          status: TransferStatus.pending,
        );
        
        _transfers[transferId] = transfer;
        notifyListeners();
        
        // TODO: Start actual transfer
        _simulateTransfer(transferId);
      }
    }
  }

  // Temporary simulation for development
  void _simulateTransfer(String transferId) {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      final transfer = _transfers[transferId];
      if (transfer == null) {
        timer.cancel();
        return;
      }

      if (transfer.progress >= 100) {
        _transfers[transferId] = transfer.copyWith(
          status: TransferStatus.completed,
          progress: 100,
          completedAt: DateTime.now(),
        );
        notifyListeners();
        timer.cancel();
        return;
      }

      _transfers[transferId] = transfer.copyWith(
        status: TransferStatus.transferring,
        progress: transfer.progress + 10,
      );
      notifyListeners();
    });
  }

  Future<void> pauseTransfer(String transferId) async {
    final transfer = _transfers[transferId];
    if (transfer != null && transfer.status == TransferStatus.transferring) {
      _transfers[transferId] = transfer.copyWith(status: TransferStatus.paused);
      notifyListeners();
    }
  }

  Future<void> resumeTransfer(String transferId) async {
    final transfer = _transfers[transferId];
    if (transfer != null && transfer.status == TransferStatus.paused) {
      _transfers[transferId] = transfer.copyWith(status: TransferStatus.transferring);
      notifyListeners();
      // TODO: Resume actual transfer
    }
  }

  Future<void> cancelTransfer(String transferId) async {
    final transfer = _transfers[transferId];
    if (transfer != null) {
      _transfers[transferId] = transfer.copyWith(status: TransferStatus.cancelled);
      notifyListeners();
      // TODO: Clean up temp files
    }
  }

  @override
  void dispose() {
    // TODO: Clean up service
    super.dispose();
  }
}
