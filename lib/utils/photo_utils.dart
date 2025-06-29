import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/photo_data.dart';
import '../services/firestore_service.dart';

class PhotoUtils {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Convert Firestore document to PhotoData
  static PhotoData? documentToPhotoData(DocumentSnapshot doc) {
    if (!doc.exists) return null;

    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PhotoData(
      id: doc.id,
      file: data['firebaseUrl'],
      firebaseUrl: data['firebaseUrl'],
      title: data['title'] ?? 'Photo Details',
      isLiked: data['isLiked'] ?? false,
      comment: data['comment'] ?? '',
      userId: data['userId'],
    );
  }

  // Save photo changes to Firestore
  static Future<void> savePhotoChanges(PhotoData photo) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('No user logged in');

      await FirestoreService.updatePhoto(photo.id, {
        'title': photo.title,
        'isLiked': photo.isLiked,
        'comment': photo.comment,
        'lastModified': FirestoreService.serverTimestamp,
      });
    } catch (e) {
      print('Error saving photo changes: $e');
      rethrow;
    }
  }

  // Load user's photos
  static Future<List<PhotoData>> loadUserPhotos({String source = 'photos_only'}) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('No user logged in');

      // Load photos from Firestore with source filter
      final QuerySnapshot snapshot = await FirestoreService.photos
          .where('userId', isEqualTo: userId)
          .where('source', isEqualTo: source)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return PhotoData(
          id: doc.id,
          file: null,
          firebaseUrl: data['firebaseUrl'] ?? data['url'],
          title: data['title'] ?? 'Photo Details',
          isLiked: data['isLiked'] ?? false,
          comment: data['comment'] ?? '',
          userId: userId,
        );
      }).toList();
    } catch (e) {
      print('Error loading photos: $e');
      rethrow;
    }
  }

  // Generate unique photo ID
  static String generatePhotoId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_auth.currentUser?.uid ?? "unknown"}';
  }

  // Format timestamp
  static String formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Format Firestore timestamp
  static String formatFirestoreTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
} 