import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

class ShareIntentHandler {
  StreamSubscription? _intentDataStreamSubscription;
  final _receiveSharingIntent = ReceiveSharingIntent.instance;

  void initialize(
    BuildContext context,
    Function(List<String>) onFilesReceived,
  ) {
    // For files shared while the app is closed
    _receiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final paths = value.map((file) => file.path).toList();
        onFilesReceived(paths);
      }
    });

    // For files shared while the app is open
    _intentDataStreamSubscription = _receiveSharingIntent
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (value.isNotEmpty) {
              final paths = value.map((file) => file.path).toList();
              onFilesReceived(paths);
            }
          },
          onError: (err) {
            debugPrint("Share intent error: $err");
          },
        );

    // For sharing text (if the package supports it in your version)
    // Note: Some versions may not have getInitialText
    try {
      // You may need to handle text sharing differently or remove if not supported
      debugPrint("Text sharing not configured");
    } catch (e) {
      debugPrint("Text sharing error: $e");
    }
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}
