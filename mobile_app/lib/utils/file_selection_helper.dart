import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class FileSelectionHelper {
  static Future<List<String>?> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      
      if (result != null && result.files.isNotEmpty) {
        return result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error picking files: $e');
      return null;
    }
  }
  
  static Future<List<String>?> pickImages() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        return images.map((image) => image.path).toList();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error picking images: $e');
      return null;
    }
  }
  
  static Future<String?> pickSingleImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      
      return image?.path;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }
  
  static Future<String?> pickVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      
      return video?.path;
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }
  
  static Future<List<String>?> pickFolder() async {
    try {
      // Note: File picker doesn't support folder selection on mobile
      // This would need platform-specific implementation
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      
      if (result != null && result.files.isNotEmpty) {
        return result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();
      }
      
      return null;
    } catch (e) {
      debugPrint('Error picking folder: $e');
      return null;
    }
  }
}
