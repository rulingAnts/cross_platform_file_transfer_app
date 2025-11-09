import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/transfer_history.dart';

/// Manager for transfer history storage and retrieval
class TransferHistoryManager {
  static const String _historyFileName = 'transfer_history.json';
  static const int _maxHistoryItems = 500; // Keep last 500 transfers
  
  /// Get the history file path
  static Future<String> _getHistoryFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_historyFileName';
  }
  
  /// Load transfer history from disk
  static Future<List<TransferHistory>> loadHistory() async {
    try {
      final filePath = await _getHistoryFilePath();
      final file = File(filePath);
      
      if (!await file.exists()) {
        return [];
      }
      
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      
      return jsonList
          .map((json) => TransferHistory.fromJson(json))
          .toList();
    } catch (e) {
      print('Error loading transfer history: $e');
      return [];
    }
  }
  
  /// Save transfer history to disk
  static Future<void> saveHistory(List<TransferHistory> history) async {
    try {
      final filePath = await _getHistoryFilePath();
      final file = File(filePath);
      
      // Keep only the most recent items
      final limitedHistory = history.length > _maxHistoryItems
          ? history.sublist(history.length - _maxHistoryItems)
          : history;
      
      final jsonList = limitedHistory.map((h) => h.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving transfer history: $e');
    }
  }
  
  /// Add a new transfer to history
  static Future<void> addTransfer(TransferHistory transfer) async {
    final history = await loadHistory();
    history.add(transfer);
    await saveHistory(history);
  }
  
  /// Get history filtered by date range
  static Future<List<TransferHistory>> getHistoryByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final history = await loadHistory();
    return history.where((t) => 
      t.completedAt.isAfter(start) && t.completedAt.isBefore(end)
    ).toList();
  }
  
  /// Get history filtered by device
  static Future<List<TransferHistory>> getHistoryByDevice(String deviceId) async {
    final history = await loadHistory();
    return history.where((t) => t.deviceId == deviceId).toList();
  }
  
  /// Get history filtered by direction
  static Future<List<TransferHistory>> getHistoryByDirection(
    TransferDirection direction,
  ) async {
    final history = await loadHistory();
    return history.where((t) => t.direction == direction).toList();
  }
  
  /// Search history by filename
  static Future<List<TransferHistory>> searchHistory(String query) async {
    final history = await loadHistory();
    final lowerQuery = query.toLowerCase();
    return history.where((t) => 
      t.fileName.toLowerCase().contains(lowerQuery)
    ).toList();
  }
  
  /// Get statistics for all transfers
  static Future<Map<String, dynamic>> getStatistics() async {
    final history = await loadHistory();
    
    if (history.isEmpty) {
      return {
        'totalTransfers': 0,
        'successfulTransfers': 0,
        'failedTransfers': 0,
        'totalBytesSent': 0,
        'totalBytesReceived': 0,
        'averageSpeed': 0.0,
        'totalDuration': Duration.zero,
      };
    }
    
    final successful = history.where((t) => t.successful).length;
    final failed = history.length - successful;
    
    final sent = history
        .where((t) => t.direction == TransferDirection.sending)
        .fold<int>(0, (sum, t) => sum + t.bytesTransferred);
    
    final received = history
        .where((t) => t.direction == TransferDirection.receiving)
        .fold<int>(0, (sum, t) => sum + t.bytesTransferred);
    
    final avgSpeed = history.fold<double>(0, (sum, t) => sum + t.averageSpeed) / 
                     history.length;
    
    final totalDuration = history.fold<Duration>(
      Duration.zero,
      (sum, t) => sum + t.duration,
    );
    
    return {
      'totalTransfers': history.length,
      'successfulTransfers': successful,
      'failedTransfers': failed,
      'totalBytesSent': sent,
      'totalBytesReceived': received,
      'averageSpeed': avgSpeed,
      'totalDuration': totalDuration,
    };
  }
  
  /// Clear all transfer history
  static Future<void> clearHistory() async {
    try {
      final filePath = await _getHistoryFilePath();
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error clearing transfer history: $e');
    }
  }
  
  /// Delete history items older than specified days
  static Future<void> cleanupOldHistory(int daysToKeep) async {
    final history = await loadHistory();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    final recentHistory = history.where((t) => 
      t.completedAt.isAfter(cutoffDate)
    ).toList();
    
    await saveHistory(recentHistory);
  }
}
