import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_archive/flutter_archive.dart';
import '../models/device.dart';
import '../models/transfer.dart';
import 'device_manager.dart';

class TransferService extends ChangeNotifier {
  final DeviceManager deviceManager;
  final Map<String, FileTransfer> _transfers = {};
  final Map<String, SecureSocket> _sockets = {};

  TransferService(this.deviceManager);

  List<FileTransfer> get transfers => _transfers.values.toList();
  
  List<FileTransfer> get activeTransfers => _transfers.values
      .where((t) => t.status == TransferStatus.transferring ||
                    t.status == TransferStatus.preparing ||
                    t.status == TransferStatus.connecting)
      .toList();

  Future<void> init() async {
    // Initialize temp directory
    final tempDir = await getTemporaryDirectory();
    final transferDir = Directory('${tempDir.path}/rapidtransfer');
    await transferDir.create(recursive: true);
  }

  Future<void> sendFiles(List<String> deviceIds, List<String> filePaths) async {
    for (final deviceId in deviceIds) {
      for (final filePath in filePaths) {
        final file = File(filePath);
        if (!await file.exists()) continue;
        
        final stats = await file.stat();
        final transferId = '${DateTime.now().millisecondsSinceEpoch}_${filePath.hashCode}';
        final fileName = filePath.split('/').last;
        
        final transfer = FileTransfer(
          id: transferId,
          deviceId: deviceId,
          filePath: filePath,
          fileName: fileName,
          size: stats.size,
          isDirectory: stats.type == FileSystemEntityType.directory,
          status: TransferStatus.pending,
        );
        
        _transfers[transferId] = transfer;
        notifyListeners();
        
        // Start transfer in background
        _startTransfer(transfer).catchError((error) {
          debugPrint('Transfer failed: $error');
          _transfers[transferId] = transfer.copyWith(
            status: TransferStatus.failed,
            error: error.toString(),
          );
          notifyListeners();
        });
      }
    }
  }

  Future<void> _startTransfer(FileTransfer transfer) async {
    try {
      // Update status to preparing
      _transfers[transfer.id] = transfer.copyWith(status: TransferStatus.preparing);
      notifyListeners();
      
      // Get temp directory
      final tempDir = await getTemporaryDirectory();
      final transferTempDir = Directory('${tempDir.path}/rapidtransfer/send/${transfer.id}');
      await transferTempDir.create(recursive: true);
      
      File fileToSend;
      int fileSize;
      
      if (transfer.isDirectory) {
        // Compress directory
        _transfers[transfer.id] = transfer.copyWith(status: TransferStatus.compressing);
        notifyListeners();
        
        final tarPath = '${transferTempDir.path}/${transfer.fileName}.tar.gz';
        await ZipFile.createFromDirectory(
          sourceDir: Directory(transfer.filePath),
          zipFile: File(tarPath),
          includeBaseDirectory: false,
        );
        
        fileToSend = File(tarPath);
        fileSize = await fileToSend.length();
      } else {
        fileToSend = File(transfer.filePath);
        fileSize = transfer.size;
      }
      
      // Calculate checksum
      _transfers[transfer.id] = transfer.copyWith(status: TransferStatus.checksumming);
      notifyListeners();
      
      final checksum = await _calculateChecksum(fileToSend);
      
      // Connect to device
      _transfers[transfer.id] = transfer.copyWith(status: TransferStatus.connecting);
      notifyListeners();
      
      final device = deviceManager.getDevice(transfer.deviceId);
      if (device == null) {
        throw Exception('Device not found');
      }
      
      final socket = await _connectToDevice(device);
      _sockets[transfer.id] = socket;
      
      // Send transfer request
      await _sendMessage(socket, 3, {
        'transferId': transfer.id,
        'fileName': transfer.fileName,
        'fileSize': fileSize,
        'checksum': checksum,
        'isDirectory': transfer.isDirectory,
      });
      
      // Wait for acceptance
      await _waitForAcceptance(socket, transfer.id);
      
      // Send file chunks
      _transfers[transfer.id] = transfer.copyWith(
        status: TransferStatus.transferring,
        progress: 0,
      );
      notifyListeners();
      
      await _sendFileChunks(socket, fileToSend, transfer);
      
      // Mark complete
      _transfers[transfer.id] = transfer.copyWith(
        status: TransferStatus.completed,
        progress: 100,
        completedAt: DateTime.now(),
      );
      notifyListeners();
      
      // Cleanup
      await transferTempDir.delete(recursive: true).catchError((_) {});
      socket.close();
      _sockets.remove(transfer.id);
      
    } catch (e) {
      debugPrint('Transfer error: $e');
      rethrow;
    }
  }

  Future<SecureSocket> _connectToDevice(Device device) async {
    return await SecureSocket.connect(
      device.address,
      device.port,
      onBadCertificate: (certificate) => true, // Accept self-signed certs
      timeout: const Duration(seconds: 30),
    );
  }

  Future<String> _calculateChecksum(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<void> _sendMessage(SecureSocket socket, int type, Map<String, dynamic> data) async {
    final jsonData = jsonEncode(data);
    final dataBytes = utf8.encode(jsonData);
    final length = dataBytes.length + 1; // +1 for type byte
    
    final message = ByteData(4 + 1 + dataBytes.length);
    message.setUint32(0, length, Endian.big);
    message.setUint8(4, type);
    
    final buffer = message.buffer.asUint8List();
    for (var i = 0; i < dataBytes.length; i++) {
      buffer[5 + i] = dataBytes[i];
    }
    
    socket.add(buffer);
    await socket.flush();
  }

  Future<void> _waitForAcceptance(SecureSocket socket, String transferId) async {
    final completer = Completer<void>();
    
    final subscription = socket.listen((data) {
      try {
        if (data.length >= 5) {
          final type = data[4];
          if (type == 4) { // TRANSFER_ACCEPT
            completer.complete();
          }
        }
      } catch (e) {
        // Ignore parsing errors
      }
    });
    
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Transfer acceptance timeout'));
      }
    });
    
    await completer.future;
    await subscription.cancel();
  }

  Future<void> _sendFileChunks(SecureSocket socket, File file, FileTransfer transfer) async {
    const chunkSize = 1024 * 1024; // 1 MB
    final fileSize = await file.length();
    final stream = file.openRead();
    
    int chunkIndex = 0;
    int totalSent = 0;
    final startTime = DateTime.now();
    
    await for (final chunk in stream) {
      // Calculate chunk checksum
      final chunkChecksum = sha256.convert(chunk).toString();
      
      // Send chunk
      await _sendMessage(socket, 5, {
        'transferId': transfer.id,
        'chunkIndex': chunkIndex++,
        'data': base64Encode(chunk),
        'checksum': chunkChecksum,
      });
      
      totalSent += chunk.length;
      
      // Update progress
      final progress = (totalSent / fileSize) * 100;
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      final speed = elapsed > 0 ? totalSent / elapsed : 0;
      
      _transfers[transfer.id] = transfer.copyWith(
        progress: progress,
        bytesTransferred: totalSent,
        speed: speed.toDouble(),
      );
      notifyListeners();
      
      // Wait for acknowledgment
      await _waitForChunkAck(socket, chunkIndex - 1);
    }
  }

  Future<void> _waitForChunkAck(SecureSocket socket, int chunkIndex) async {
    final completer = Completer<void>();
    
    final subscription = socket.listen((data) {
      try {
        if (data.length >= 5) {
          final type = data[4];
          if (type == 6) { // CHUNK_ACK
            final jsonData = utf8.decode(data.sublist(5));
            final message = jsonDecode(jsonData);
            if (message['chunkIndex'] == chunkIndex) {
              completer.complete();
            }
          }
        }
      } catch (e) {
        // Ignore parsing errors
      }
    });
    
    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('Chunk acknowledgment timeout'));
      }
    });
    
    await completer.future;
    await subscription.cancel();
  }

  Future<void> pauseTransfer(String transferId) async {
    final transfer = _transfers[transferId];
    if (transfer != null && transfer.status == TransferStatus.transferring) {
      _transfers[transferId] = transfer.copyWith(status: TransferStatus.paused);
      notifyListeners();
      
      // Close socket
      _sockets[transferId]?.close();
      _sockets.remove(transferId);
    }
  }

  Future<void> resumeTransfer(String transferId) async {
    final transfer = _transfers[transferId];
    if (transfer != null && transfer.status == TransferStatus.paused) {
      // Restart transfer
      await _startTransfer(transfer);
    }
  }

  Future<void> cancelTransfer(String transferId) async {
    final transfer = _transfers[transferId];
    if (transfer != null) {
      _transfers[transferId] = transfer.copyWith(status: TransferStatus.cancelled);
      notifyListeners();
      
      // Close socket
      _sockets[transferId]?.close();
      _sockets.remove(transferId);
      
      // Cleanup temp files
      final tempDir = await getTemporaryDirectory();
      final transferTempDir = Directory('${tempDir.path}/rapidtransfer/send/$transferId');
      await transferTempDir.delete(recursive: true).catchError((_) {});
    }
  }

  @override
  void dispose() {
    // Close all sockets
    for (final socket in _sockets.values) {
      socket.close();
    }
    _sockets.clear();
    super.dispose();
  }
}
