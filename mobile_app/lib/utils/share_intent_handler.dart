import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'dart:async';

class ShareIntentHandler {
  StreamSubscription? _intentDataStreamSubscription;
  
  void initialize(BuildContext context, Function(List<String>) onFilesReceived) {
    // For files shared while the app is closed
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final paths = value.map((file) => file.path).toList();
        onFilesReceived(paths);
      }
    });

    // For files shared while the app is open
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final paths = value.map((file) => file.path).toList();
        onFilesReceived(paths);
      }
    }, onError: (err) {
      debugPrint("Share intent error: $err");
    });

    // For sharing text
    ReceiveSharingIntent.getInitialText().then((String? value) {
      if (value != null && value.isNotEmpty) {
        debugPrint("Shared text: $value");
        // Could save text as a file and share it
      }
    });
  }
  
  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}
