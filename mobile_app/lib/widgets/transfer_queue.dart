import 'package:flutter/material.dart';
import '../models/transfer.dart';

class TransferQueue extends StatelessWidget {
  final List<FileTransfer> transfers;
  final Function(String) onPause;
  final Function(String) onResume;
  final Function(String) onCancel;

  const TransferQueue({
    super.key,
    required this.transfers,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No active transfers',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return _TransferItem(
          transfer: transfer,
          onPause: () => onPause(transfer.id),
          onResume: () => onResume(transfer.id),
          onCancel: () => onCancel(transfer.id),
        );
      },
    );
  }
}

class _TransferItem extends StatelessWidget {
  final FileTransfer transfer;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const _TransferItem({
    required this.transfer,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  transfer.isDirectory ? Icons.folder : Icons.insert_drive_file,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transfer.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildActionButtons(context),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            LinearProgressIndicator(
              value: transfer.progress / 100,
              backgroundColor: Colors.grey[200],
              color: _getProgressColor(context),
            ),
            const SizedBox(height: 8),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transfer.statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${transfer.progress.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (transfer.size > 0)
              Text(
                transfer.formatSize(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            if (transfer.speed != null && transfer.speed! > 0)
              Text(
                '${transfer.formatSpeed()} • ETA: ${_formatDuration(transfer.estimatedTimeRemaining)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (transfer.status == TransferStatus.transferring)
          IconButton(
            icon: const Icon(Icons.pause, size: 20),
            onPressed: onPause,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Pause',
          ),
        if (transfer.status == TransferStatus.paused)
          IconButton(
            icon: const Icon(Icons.play_arrow, size: 20),
            onPressed: onResume,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Resume',
          ),
        const SizedBox(width: 8),
        if (transfer.status != TransferStatus.completed &&
            transfer.status != TransferStatus.cancelled)
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              _showCancelDialog(context);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Cancel',
          ),
      ],
    );
  }

  Color _getProgressColor(BuildContext context) {
    switch (transfer.status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
      case TransferStatus.cancelled:
        return Colors.red;
      case TransferStatus.paused:
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Transfer'),
        content: const Text(
          'Are you sure you want to cancel this transfer? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onCancel();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}
