import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/photo_data.dart';

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Thumbnail sizes
  static const int thumbnailSize = 200;
  static const int mediumSize = 400;
  static const int fullSize = 1080;

  /// Upload image with 3 sizes: thumbnail, medium, and full (WebP + JPEG fallbacks)
  static Future<Map<String, String>> uploadImageWithThumbnails({
    required XFile imageFile,
    required String userId,
    required String photoId,
    String? albumName,
  }) async {
    try {
      print('🔄 Starting image upload with thumbnails for photo: $photoId');
      
      // Get the original image bytes
      final originalBytes = await imageFile.readAsBytes();
      print('📸 Original image size: ${originalBytes.length} bytes');

      // Generate WebP versions (preferred)
      final thumbnailWebP = await _compressImage(originalBytes, thumbnailSize);
      final mediumWebP = await _compressImage(originalBytes, mediumSize);
      final fullWebP = await _compressImage(originalBytes, fullSize);

      // Generate JPEG fallbacks
      final thumbnailJPEG = await _compressImageJPEG(originalBytes, thumbnailSize);
      final mediumJPEG = await _compressImageJPEG(originalBytes, mediumSize);
      final fullJPEG = await _compressImageJPEG(originalBytes, fullSize);

      print('📏 Generated WebP sizes - Thumbnail: ${thumbnailWebP.length}, Medium: ${mediumWebP.length}, Full: ${fullWebP.length}');
      print('📏 Generated JPEG sizes - Thumbnail: ${thumbnailJPEG.length}, Medium: ${mediumJPEG.length}, Full: ${fullJPEG.length}');

      // Upload WebP versions (primary)
      final thumbnailUrl = await _uploadToStorage(thumbnailWebP, 'thumbnails', userId, '${photoId}.webp');
      final mediumUrl = await _uploadToStorage(mediumWebP, 'medium', userId, '${photoId}.webp');
      final fullUrl = await _uploadToStorage(fullWebP, 'full', userId, '${photoId}.webp');

      // Upload JPEG fallbacks
      final thumbnailUrlJPEG = await _uploadToStorage(thumbnailJPEG, 'thumbnails', userId, '${photoId}.jpg');
      final mediumUrlJPEG = await _uploadToStorage(mediumJPEG, 'medium', userId, '${photoId}.jpg');
      final fullUrlJPEG = await _uploadToStorage(fullJPEG, 'full', userId, '${photoId}.jpg');

      print('✅ All thumbnails uploaded successfully (WebP + JPEG)');

      return {
        'thumbnailUrl': thumbnailUrl,
        'mediumUrl': mediumUrl,
        'fullUrl': fullUrl,
        'thumbnailUrlJPEG': thumbnailUrlJPEG,
        'mediumUrlJPEG': mediumUrlJPEG,
        'fullUrlJPEG': fullUrlJPEG,
      };
    } catch (e) {
      print('❌ Error generating thumbnails: $e');
      // Fallback to original image
      final originalBytes = await imageFile.readAsBytes();
      final originalUrl = await _uploadToStorage(originalBytes, 'photos', userId, photoId);
      return {
        'thumbnailUrl': originalUrl,
        'mediumUrl': originalUrl,
        'fullUrl': originalUrl,
        'thumbnailUrlJPEG': originalUrl,
        'mediumUrlJPEG': originalUrl,
        'fullUrlJPEG': originalUrl,
      };
    }
  }

  /// Compress image to WebP format
  static Future<Uint8List> _compressImage(Uint8List imageBytes, int maxSize) async {
    try {
      final webpBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: maxSize,
        minHeight: maxSize,
        quality: maxSize == thumbnailSize ? 85 : 90,
        format: CompressFormat.webp,
      );
      
      if (webpBytes != null && webpBytes.isNotEmpty) {
        print('✅ Generated WebP: ${webpBytes.length} bytes');
        return webpBytes;
      }
      
      print('⚠️ WebP compression failed, using original');
      return imageBytes;
    } catch (e) {
      print('⚠️ WebP compression failed: $e');
      return imageBytes;
    }
  }

  /// Compress image to JPEG format (fallback)
  static Future<Uint8List> _compressImageJPEG(Uint8List imageBytes, int maxSize) async {
    try {
      final jpegBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: maxSize,
        minHeight: maxSize,
        quality: maxSize == thumbnailSize ? 85 : 90,
        format: CompressFormat.jpeg,
      );
      
      if (jpegBytes != null && jpegBytes.isNotEmpty) {
        print('✅ Generated JPEG: ${jpegBytes.length} bytes');
        return jpegBytes;
      }
      
      print('⚠️ JPEG compression failed, using original');
      return imageBytes;
    } catch (e) {
      print('⚠️ JPEG compression failed: $e');
      return imageBytes;
    }
  }

  /// Upload bytes to Firebase Storage
  static Future<String> _uploadToStorage(Uint8List bytes, String folder, String userId, String photoId) async {
    try {
      final ref = _storage.ref().child('$folder/$userId/$photoId');
      final uploadTask = ref.putData(bytes);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('❌ Upload failed for $folder: $e');
      rethrow;
    }
  }

  /// Save photo data to Firestore with thumbnail URLs (WebP + JPEG)
  static Future<void> savePhotoToFirestore({
    required String photoId,
    required String userId,
    required Map<String, String> imageUrls,
    String? albumName,
    String? title,
    String? comment,
  }) async {
    try {
      final photoData = {
        'id': photoId,
        'userId': userId,
        'url': imageUrls['fullUrl'], // Keep original field for compatibility
        'firebaseUrl': imageUrls['fullUrl'], // Keep original field for compatibility
        'thumbnailUrl': imageUrls['thumbnailUrl'], // WebP version
        'mediumUrl': imageUrls['mediumUrl'], // WebP version
        'fullUrl': imageUrls['fullUrl'], // WebP version
        'thumbnailUrlJPEG': imageUrls['thumbnailUrlJPEG'], // JPEG fallback
        'mediumUrlJPEG': imageUrls['mediumUrlJPEG'], // JPEG fallback
        'fullUrlJPEG': imageUrls['fullUrlJPEG'], // JPEG fallback
        'title': title ?? 'Photo Details',
        'comment': comment ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'isLiked': false,
        // Phase 2: Cache like data to reduce Firestore reads
        'recentLikers': [], // Empty array for new photos
        'likesMap': {}, // Empty map for new photos
      };

      if (albumName != null) {
        photoData['albumName'] = albumName;
      }

      await _firestore.collection('photos').doc(photoId).set(photoData);
      print('✅ Photo saved to Firestore with WebP + JPEG thumbnails');
    } catch (e) {
      print('❌ Error saving photo to Firestore: $e');
      rethrow;
    }
  }
}