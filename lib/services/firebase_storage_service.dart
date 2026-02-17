import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  static final FirebaseStorageService _instance =
      FirebaseStorageService._internal();

  factory FirebaseStorageService() {
    return _instance;
  }

  FirebaseStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get a list of all image files in a specific folder
  Future<List<String>> listImages({required String folderPath}) async {
    try {
      final ListResult result = await _storage.ref(folderPath).listAll();
      final imageUrls = <String>[];

      for (var item in result.items) {
        imageUrls.add(item.fullPath);
      }

      debugPrint('📸 Found ${imageUrls.length} images in $folderPath');
      return imageUrls;
    } catch (e) {
      debugPrint('❌ Error listing images: $e');
      rethrow;
    }
  }

  /// Get download URL for an image
  Future<String> getDownloadUrl({required String imagePath}) async {
    try {
      final url = await _storage.ref(imagePath).getDownloadURL();
      return url;
    } catch (e) {
      debugPrint('❌ Error getting download URL: $e');
      rethrow;
    }
  }

  /// Upload an image file to Firebase Storage
  Future<String> uploadImage({
    required String localFilePath,
    required String remotePath,
  }) async {
    try {
      await _storage.ref(remotePath).putFile(File(localFilePath));
      final downloadUrl = await getDownloadUrl(imagePath: remotePath);
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      rethrow;
    }
  }

  /// Delete an image from Firebase Storage
  Future<void> deleteImage({required String imagePath}) async {
    try {
      await _storage.ref(imagePath).delete();
      debugPrint('🗑️  Image deleted: $imagePath');
    } catch (e) {
      debugPrint('❌ Error deleting image: $e');
      rethrow;
    }
  }

  /// Stream images metadata from a folder
  Stream<List<Reference>> streamImages({required String folderPath}) {
    return Stream.fromFuture(
      _storage.ref(folderPath).listAll().then((result) => result.items),
    );
  }
}
