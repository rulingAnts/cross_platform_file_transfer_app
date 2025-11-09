import 'package:flutter/material.dart';
import '../models/transfer_history.dart';
import '../services/transfer_history_manager.dart';

class TransferHistoryScreen extends StatefulWidget {
  const TransferHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  List<TransferHistory> _history = [];
  List<TransferHistory> _filteredHistory = [];
  bool _isLoading = true;
  String _searchQuery = '';
  TransferDirection? _filterDirection;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final history = await TransferHistoryManager.loadHistory();
      setState(() {
        _history = history.reversed.toList(); // Most recent first
        _filteredHistory = _history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load history: $e')),
        );
      }
    }
  }

  void _filterHistory() {
    setState(() {
      _filteredHistory = _history.where((transfer) {
        // Apply search filter
        if (_searchQuery.isNotEmpty &&
            !transfer.fileName.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
        
        // Apply direction filter
        if (_filterDirection != null && transfer.direction != _filterDirection) {
          return false;
        }
        
        return true;
      }).toList();
    });
  }

  Future<void> _showStatistics() async {
    final stats = await TransferHistoryManager.getStatistics();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer Statistics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('Total Transfers', '${stats['totalTransfers']}'),
              _buildStatRow('Successful', '${stats['successfulTransfers']}'),
              _buildStatRow('Failed', '${stats['failedTransfers']}'),
              const Divider(),
              _buildStatRow('Total Sent', _formatBytes(stats['totalBytesSent'])),
              _buildStatRow('Total Received', _formatBytes(stats['totalBytesReceived'])),
              const Divider(),
              _buildStatRow('Average Speed', '${(stats['averageSpeed'] / (1024 * 1024)).toStringAsFixed(1)} MB/s'),
              _buildStatRow('Total Duration', _formatDuration(stats['totalDuration'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all transfer history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TransferHistoryManager.clearHistory();
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showStatistics,
            tooltip: 'Statistics',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear History'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search files...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterHistory();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<TransferDirection?>(
                  value: _filterDirection,
                  hint: const Text('All'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(
                      value: TransferDirection.sending,
                      child: Text('Sent'),
                    ),
                    DropdownMenuItem(
                      value: TransferDirection.receiving,
                      child: Text('Received'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _filterDirection = value;
                      _filterHistory();
                    });
                  },
                ),
              ],
            ),
          ),
          
          // History list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistory.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching transfers found'
                                  : 'No transfer history yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredHistory.length,
                        itemBuilder: (context, index) {
                          final transfer = _filteredHistory[index];
                          return _buildHistoryItem(transfer);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(TransferHistory transfer) {
    final isSending = transfer.direction == TransferDirection.sending;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: transfer.successful
              ? (isSending ? Colors.blue : Colors.green)
              : Colors.red,
          child: Icon(
            isSending ? Icons.upload : Icons.download,
            color: Colors.white,
          ),
        ),
        title: Text(
          transfer.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${isSending ? 'To' : 'From'}: ${transfer.deviceName}'),
            Text(
              '${transfer.formattedFileSize} • ${transfer.formattedSpeed} • ${transfer.formattedDuration}',
              style: const TextStyle(fontSize: 12),
            ),
            if (!transfer.successful && transfer.errorMessage != null)
              Text(
                'Error: ${transfer.errorMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        trailing: Text(
          _formatDate(transfer.completedAt),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
