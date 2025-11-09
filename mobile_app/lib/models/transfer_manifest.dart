import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class TransferManifest {
  final String transferId;
  final String fileName;
  final int fileSize;
  final String checksum;
  final bool isDirectory;
  final String deviceId;
  final List<ChunkInfo> chunks;
  final DateTime createdAt;
  final DateTime lastActivity;
  
  TransferManifest({
    required this.transferId,
    required this.fileName,
    required this.fileSize,
    required this.checksum,
    required this.isDirectory,
    required this.deviceId,
    required this.chunks,
    DateTime? createdAt,
    DateTime? lastActivity,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastActivity = lastActivity ?? DateTime.now();
  
  Map<String, dynamic> toJson() {
    return {
      'transferId': transferId,
      'fileName': fileName,
      'fileSize': fileSize,
      'checksum': checksum,
      'isDirectory': isDirectory,
      'deviceId': deviceId,
      'chunks': chunks.map((c) => c.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastActivity': lastActivity.toIso8601String(),
    };
  }
  
  factory TransferManifest.fromJson(Map<String, dynamic> json) {
    return TransferManifest(
      transferId: json['transferId'],
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      checksum: json['checksum'],
      isDirectory: json['isDirectory'] ?? false,
      deviceId: json['deviceId'],
      chunks: (json['chunks'] as List).map((c) => ChunkInfo.fromJson(c)).toList(),
      createdAt: DateTime.parse(json['createdAt']),
      lastActivity: DateTime.parse(json['lastActivity']),
    );
  }
  
  int get receivedChunks => chunks.where((c) => c.received).length;
  int get totalChunks => chunks.length;
  double get progress => (receivedChunks / totalChunks) * 100;
  
  bool get isComplete => receivedChunks == totalChunks;
  
  bool get isExpired {
    // Expired if no activity for more than 24 hours
    return DateTime.now().difference(lastActivity).inHours > 24;
  }
  
  TransferManifest copyWith({
    DateTime? lastActivity,
    List<ChunkInfo>? chunks,
  }) {
    return TransferManifest(
      transferId: transferId,
      fileName: fileName,
      fileSize: fileSize,
      checksum: checksum,
      isDirectory: isDirectory,
      deviceId: deviceId,
      chunks: chunks ?? this.chunks,
      createdAt: createdAt,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }
}

class ChunkInfo {
  final int index;
  final int size;
  final String checksum;
  final bool received;
  
  ChunkInfo({
    required this.index,
    required this.size,
    required this.checksum,
    this.received = false,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'size': size,
      'checksum': checksum,
      'received': received,
    };
  }
  
  factory ChunkInfo.fromJson(Map<String, dynamic> json) {
    return ChunkInfo(
      index: json['index'],
      size: json['size'],
      checksum: json['checksum'],
      received: json['received'] ?? false,
    );
  }
  
  ChunkInfo copyWith({bool? received}) {
    return ChunkInfo(
      index: index,
      size: size,
      checksum: checksum,
      received: received ?? this.received,
    );
  }
}

class ManifestManager {
  static Future<String> _getManifestDir() async {
    final tempDir = await getTemporaryDirectory();
    final manifestDir = Directory('${tempDir.path}/rapidtransfer/manifests');
    await manifestDir.create(recursive: true);
    return manifestDir.path;
  }
  
  static Future<void> saveManifest(TransferManifest manifest) async {
    try {
      final dir = await _getManifestDir();
      final file = File('$dir/${manifest.transferId}.json');
      await file.writeAsString(jsonEncode(manifest.toJson()));
      debugPrint('Manifest saved: ${manifest.transferId}');
    } catch (e) {
      debugPrint('Failed to save manifest: $e');
    }
  }
  
  static Future<TransferManifest?> loadManifest(String transferId) async {
    try {
      final dir = await _getManifestDir();
      final file = File('$dir/$transferId.json');
      
      if (!await file.exists()) {
        return null;
      }
      
      final jsonStr = await file.readAsString();
      final json = jsonDecode(jsonStr);
      return TransferManifest.fromJson(json);
    } catch (e) {
      debugPrint('Failed to load manifest: $e');
      return null;
    }
  }
  
  static Future<List<TransferManifest>> loadAllManifests() async {
    try {
      final dir = await _getManifestDir();
      final directory = Directory(dir);
      
      if (!await directory.exists()) {
        return [];
      }
      
      final files = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .toList();
      
      final manifests = <TransferManifest>[];
      
      for (final file in files) {
        final jsonStr = await (file as File).readAsString();
        final json = jsonDecode(jsonStr);
        manifests.add(TransferManifest.fromJson(json));
      }
      
      return manifests;
    } catch (e) {
      debugPrint('Failed to load manifests: $e');
      return [];
    }
  }
  
  static Future<void> deleteManifest(String transferId) async {
    try {
      final dir = await _getManifestDir();
      final file = File('$dir/$transferId.json');
      
      if (await file.exists()) {
        await file.delete();
        debugPrint('Manifest deleted: $transferId');
      }
    } catch (e) {
      debugPrint('Failed to delete manifest: $e');
    }
  }
  
  static Future<void> cleanupExpiredManifests() async {
    try {
      final manifests = await loadAllManifests();
      
      for (final manifest in manifests) {
        if (manifest.isExpired) {
          await deleteManifest(manifest.transferId);
        }
      }
      
      debugPrint('Cleaned up expired manifests');
    } catch (e) {
      debugPrint('Failed to cleanup manifests: $e');
    }
  }
  
  static Future<List<TransferManifest>> getResumableTransfers() async {
    final manifests = await loadAllManifests();
    return manifests.where((m) => !m.isComplete && !m.isExpired).toList();
  }
}
