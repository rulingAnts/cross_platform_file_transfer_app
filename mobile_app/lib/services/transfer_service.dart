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
import '../models/transfer_manifest.dart';
import '../utils/wake_lock_helper.dart';
import 'device_manager.dart';

class TransferService extends ChangeNotifier {
  final DeviceManager deviceManager;
  final Map<String, FileTransfer> _transfers = {};
  final Map<String, SecureSocket> _sockets = {};
  SecureServerSocket? _server;
  final int _serverPort = 8765;

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
    
    // Start TLS server to receive files
    await _startServer();
    
    // Cleanup expired manifests
    await ManifestManager.cleanupExpiredManifests();
    
    // Check for resumable transfers
    await _checkResumableTransfers();
  }
  
  Future<void> _checkResumableTransfers() async {
    final resumable = await ManifestManager.getResumableTransfers();
    
    if (resumable.isNotEmpty) {
      debugPrint('Found ${resumable.length} resumable transfer(s)');
      
      // Add them to transfers list with paused status
      for (final manifest in resumable) {
        final transfer = FileTransfer(
          id: manifest.transferId,
          deviceId: manifest.deviceId,
          filePath: '',
          fileName: manifest.fileName,
          size: manifest.fileSize,
          isDirectory: manifest.isDirectory,
          status: TransferStatus.paused,
          progress: manifest.progress,
        );
        
        _transfers[manifest.transferId] = transfer;
      }
      
      notifyListeners();
    }
  }
  
  Future<void> _startServer() async {
    try {
      // Generate self-signed certificate for mobile
      final context = SecurityContext()
        ..setTrustedCertificatesBytes(_generateSelfSignedCert().codeUnits)
        ..useCertificateChainBytes(_generateSelfSignedCert().codeUnits)
        ..usePrivateKeyBytes(_generatePrivateKey().codeUnits);
      
      _server = await SecureServerSocket.bind(
        InternetAddress.anyIPv4,
        _serverPort,
        context,
      );
      
      debugPrint('Transfer server started on port $_serverPort');
      
      _server!.listen((socket) {
        debugPrint('Incoming connection from ${socket.remoteAddress}');
        _handleIncomingConnection(socket);
      });
    } catch (e) {
      debugPrint('Failed to start server: $e');
    }
  }
  
  String _generateSelfSignedCert() {
    // Simplified self-signed cert for mobile
    // In production, use proper certificate generation
    return '''-----BEGIN CERTIFICATE-----
MIICpDCCAYwCCQDU7T8LHmA5YzANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAlS
YXBpZFRyYW5zZmVyMB4XDTIzMDEwMTAwMDAwMFoXDTMzMDEwMTAwMDAwMFowFDES
MBAGA1UEAwwJUmFwaWRUcmFuc2ZlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
AQoCggEBAMxkSv7VxYzQxMt6vGdkQ3l6FvqLxQFqJm8xQxJ0YtPxJqZY2xJ0Ytex
JqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY
2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0
YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPx
JqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY
2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0YtPxJqZY2xJ0
YtPxJqZY2xIwIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQCMZEr+1cWM0MTLerxnZE
N5ehb6i8UBaiZvMUMSdGLT8SamWNsSdGLXsSamWNsSdGLT8SamWNsSdGLT8SamWN
sSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdG
LT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8S
amWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWN
sSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdG
LT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8S
amWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWN
sSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdG
-----END CERTIFICATE-----''';
  }
  
  String _generatePrivateKey() {
    // Simplified private key for mobile
    return '''-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDMZEr+1cWM0MTL
erxnZEN5ehb6i8UBaiZvMUMSdGLT8SamWNsSdGLXsSamWNsSdGLT8SamWNsSdGLT
8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8Sam
WNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsS
dGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT
8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8Sam
WNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsS
dGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSdGLT8SamWNsSIwIDAQABAoIBADMZ
Er+1cWM0MTLerxnZEN5ehb6i8UBaiZvMUMSdGLT8SamWNsSdGLXsSamWNsSdGLT
-----END PRIVATE KEY-----''';
  }
  
  Future<void> _handleIncomingConnection(SecureSocket socket) async {
    try {
      final buffer = <int>[];
      
      await for (final data in socket) {
        buffer.addAll(data);
        await _processIncomingBuffer(socket, buffer);
      }
    } catch (e) {
      debugPrint('Error handling incoming connection: $e');
    } finally {
      socket.close();
    }
  }
  
  Future<void> _processIncomingBuffer(SecureSocket socket, List<int> buffer) async {
    while (buffer.length >= 5) {
      // Parse message: [length:4][type:1][data]
      final length = ByteData.sublistView(Uint8List.fromList(buffer.take(4).toList())).getUint32(0, Endian.big);
      
      if (buffer.length < 4 + length) {
        break; // Wait for more data
      }
      
      final type = buffer[4];
      final data = buffer.sublist(5, 4 + length);
      buffer.removeRange(0, 4 + length);
      
      await _handleIncomingMessage(socket, type, data);
    }
  }
  
  Future<void> _handleIncomingMessage(SecureSocket socket, int type, List<int> data) async {
    try {
      final message = jsonDecode(utf8.decode(data));
      
      switch (type) {
        case 3: // TRANSFER_REQUEST
          await _handleIncomingTransferRequest(socket, message);
          break;
        case 5: // CHUNK_DATA
          await _handleIncomingChunk(socket, message);
          break;
        default:
          debugPrint('Unknown incoming message type: $type');
      }
    } catch (e) {
      debugPrint('Error handling incoming message: $e');
    }
  }
  
  Future<void> _handleIncomingTransferRequest(SecureSocket socket, Map<String, dynamic> message) async {
    final transferId = message['transferId'];
    final fileName = message['fileName'];
    final fileSize = message['fileSize'];
    final checksum = message['checksum'];
    final isDirectory = message['isDirectory'] ?? false;
    
    debugPrint('Incoming transfer: $fileName ($fileSize bytes)');
    
    // Create incoming transfer
    final tempDir = await getTemporaryDirectory();
    final incomingPath = '${tempDir.path}/rapidtransfer/receive/$transferId';
    await Directory(incomingPath).create(recursive: true);
    
    final transfer = FileTransfer(
      id: transferId,
      deviceId: 'incoming',
      filePath: incomingPath,
      fileName: fileName,
      size: fileSize,
      isDirectory: isDirectory,
      status: TransferStatus.transferring,
    );
    
    _transfers[transferId] = transfer;
    _sockets[transferId] = socket;
    notifyListeners();
    
    // Send acceptance
    await _sendMessage(socket, 4, {'transferId': transferId, 'accepted': true});
  }
  
  Future<void> _handleIncomingChunk(SecureSocket socket, Map<String, dynamic> message) async {
    final transferId = message['transferId'];
    final chunkIndex = message['chunkIndex'];
    final data = message['data'];
    final checksum = message['checksum'];
    
    final transfer = _transfers[transferId];
    if (transfer == null) {
      debugPrint('Transfer not found: $transferId');
      return;
    }
    
    try {
      // Decode and verify chunk
      final chunkBytes = base64Decode(data);
      final calculatedChecksum = sha256.convert(chunkBytes).toString();
      
      if (calculatedChecksum != checksum) {
        throw Exception('Chunk checksum mismatch');
      }
      
      // Write chunk to file
      final chunkFile = File('${transfer.filePath}/chunk_$chunkIndex');
      await chunkFile.writeAsBytes(chunkBytes);
      
      // Update progress
      final currentSize = (transfer.bytesTransferred ?? 0) + chunkBytes.length;
      final progress = (currentSize / transfer.size) * 100;
      
      _transfers[transferId] = transfer.copyWith(
        bytesTransferred: currentSize,
        progress: progress,
      );
      notifyListeners();
      
      // Send acknowledgment
      await _sendMessage(socket, 6, {
        'transferId': transferId,
        'chunkIndex': chunkIndex,
        'success': true,
      });
      
      // Check if transfer complete
      if (currentSize >= transfer.size) {
        await _finalizeIncomingTransfer(transfer);
      }
    } catch (e) {
      debugPrint('Error handling incoming chunk: $e');
      await _sendMessage(socket, 6, {
        'transferId': transferId,
        'chunkIndex': chunkIndex,
        'success': false,
        'error': e.toString(),
      });
    }
  }
  
  Future<void> _finalizeIncomingTransfer(FileTransfer transfer) async {
    try {
      // Merge chunks
      final chunkFiles = await Directory(transfer.filePath)
          .list()
          .where((entity) => entity is File && entity.path.contains('chunk_'))
          .toList();
      
      chunkFiles.sort((a, b) {
        final aIndex = int.parse(a.path.split('chunk_').last);
        final bIndex = int.parse(b.path.split('chunk_').last);
        return aIndex.compareTo(bIndex);
      });
      
      final finalFile = File('${transfer.filePath}/${transfer.fileName}');
      final sink = finalFile.openWrite();
      
      for (final chunkFile in chunkFiles) {
        final bytes = await (chunkFile as File).readAsBytes();
        sink.add(bytes);
        await chunkFile.delete();
      }
      
      await sink.close();
      
      // Move to Downloads
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      final finalPath = '${downloadsDir.path}/${transfer.fileName}';
      
      // Decompress if directory
      if (transfer.isDirectory) {
        final extractDir = Directory(finalPath.replaceAll('.tar.gz', '').replaceAll('.zip', ''));
        await ZipFile.extractToDirectory(
          zipFile: finalFile,
          destinationDir: extractDir,
        );
        await finalFile.delete();
      } else {
        await finalFile.rename(finalPath);
      }
      
      // Update transfer status
      _transfers[transfer.id] = transfer.copyWith(
        status: TransferStatus.completed,
        progress: 100,
        completedAt: DateTime.now(),
      );
      notifyListeners();
      
      // Clean up temp directory
      await Directory(transfer.filePath).delete(recursive: true).catchError((_) {});
      
      debugPrint('Transfer complete: ${transfer.fileName}');
    } catch (e) {
      debugPrint('Error finalizing transfer: $e');
      _transfers[transfer.id] = transfer.copyWith(
        status: TransferStatus.failed,
        error: e.toString(),
      );
      notifyListeners();
    }
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
    // Enable wake lock if setting is on
    if (deviceManager.keepAwake) {
      await WakeLockHelper.enable();
    }
    
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
      
      // Disable wake lock if no more active transfers
      if (activeTransfers.isEmpty) {
        await WakeLockHelper.disable();
      }
      
    } catch (e) {
      debugPrint('Transfer error: $e');
      
      // Disable wake lock if no more active transfers
      if (activeTransfers.isEmpty) {
        await WakeLockHelper.disable();
      }
      
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
    // Close server
    _server?.close();
    
    // Close all sockets
    for (final socket in _sockets.values) {
      socket.close();
    }
    _sockets.clear();
    super.dispose();
  }
}
