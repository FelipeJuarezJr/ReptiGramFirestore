import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/photo_data.dart';

class PhotoUtils {
  static final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Convert database snapshot to PhotoData
  static PhotoData? snapshotToPhotoData(DataSnapshot snapshot, String photoId) {
    if (snapshot.value == null) return null;

    final Map<dynamic, dynamic> data = snapshot.value as Map;
    return PhotoData(
      id: photoId,
      file: data['firebaseUrl'],
      firebaseUrl: data['firebaseUrl'],
      title: data['title'] ?? 'Photo Details',
      isLiked: data['isLiked'] ?? false,
      comment: data['comment'] ?? '',
      userId: data['userId'],
    );
  }

  // Save photo changes to database
  static Future<void> savePhotoChanges(PhotoData photo) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('No user logged in');

      await _dbRef
          .child('users')
          .child(userId)
          .child('photos')
          .child(photo.id)
          .update({
        'title': photo.title,
        'isLiked': photo.isLiked,
        'comment': photo.comment,
        'lastModified': ServerValue.timestamp,
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

      // Load all photos first
      final DataSnapshot snapshot = await _dbRef
          .child('users')
          .child(userId)
          .child('photos')
          .get();

      if (snapshot.value == null) return [];

      final Map<dynamic, dynamic> photosMap = snapshot.value as Map;
      final List<PhotoData> photos = [];

      // Filter by source in memory
      photosMap.forEach((key, value) {
        if (value['source'] == source) {  // Filter locally
          photos.add(PhotoData(
            id: key,
            file: null,
            firebaseUrl: value['firebaseUrl'] ?? value['url'],
            title: value['title'] ?? 'Photo Details',
            isLiked: value['isLiked'] ?? false,
            comment: value['comment'] ?? '',
            userId: userId,
          ));
        }
      });

      return photos;
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
} 