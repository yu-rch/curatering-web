import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ImageUtils {
  /// Convert base64 string to Flutter Image widget
  static Image? base64ToImage(String base64String) {
    try {
      // Remove data URL prefix if present
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }

      // Decode base64
      final bytes = base64Decode(cleanBase64);

      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) {
          debugPrint('Error loading image from base64: $error');
          return const Icon(Icons.error, color: Colors.red);
        },
      );
    } catch (e) {
      debugPrint('Error converting base64 to image: $e');
      return null;
    }
  }

  /// Convert base64 string to ui.Image
  static Future<ui.Image?> base64ToUiImage(String base64String) async {
    try {
      // Remove data URL prefix if present
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }

      // Decode base64
      final bytes = base64Decode(cleanBase64);

      // Create codec for decoding
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(bytes),
        targetWidth: 512,
        targetHeight: 512,
      );

      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error converting base64 to ui.Image: $e');
      return null;
    }
  }

  /// Convert ui.Image to base64 string
  static Future<String?> uiImageToBase64(
    ui.Image image, {
    double quality = 0.8,
  }) async {
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      return base64Encode(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error converting ui.Image to base64: $e');
      return null;
    }
  }

  /// Pick image from gallery and convert to base64
  static Future<String?> pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return null;

      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick image from camera and convert to base64
  static Future<String?> pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) return null;

      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// Save base64 image to file
  static Future<String?> saveBase64ToFile(
    String base64String,
    String fileName,
  ) async {
    try {
      // Remove data URL prefix if present
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',')[1];
      }

      final bytes = base64Decode(cleanBase64);

      // Get temporary directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName.png';

      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      debugPrint('Error saving base64 to file: $e');
      return null;
    }
  }

  /// Resize image to specified dimensions
  static Future<ui.Image?> resizeImage(
    ui.Image image,
    int width,
    int height,
  ) async {
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return null;

      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
        targetWidth: width,
        targetHeight: height,
      );

      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error resizing image: $e');
      return null;
    }
  }
}

/// Helper class for managing context
class ContextManager {
  static void attach(BuildContext context) {
    // This is a placeholder - in real implementation,
    // you'd need to properly manage widget context
  }
}
