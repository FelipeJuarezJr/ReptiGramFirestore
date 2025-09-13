import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/photo_data.dart';

class PaginatedPhotosService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const int _pageSize = 20;
  static DocumentSnapshot? _lastDocument;
  static bool _hasMoreData = true;
  static bool _isLoading = false;

  /// Load photos with pagination
  static Future<List<PhotoData>> loadPhotos({
    int pageSize = _pageSize,
    bool resetPagination = false,
  }) async {
    if (_isLoading) return [];
    
    _isLoading = true;
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return [];

      if (resetPagination) {
        _lastDocument = null;
        _hasMoreData = true;
      }

      if (!_hasMoreData) return [];

      Query query = _firestore
          .collection('photos')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        _hasMoreData = false;
        return [];
      }

      _lastDocument = snapshot.docs.last;
      _hasMoreData = snapshot.docs.length == pageSize;

      final photos = <PhotoData>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final photoId = doc.id;
        
        // Get like status
        final likeDoc = await _firestore
            .collection('photos')
            .doc(photoId)
            .collection('likes')
            .doc(userId)
            .get();
        final isLiked = likeDoc.exists;

        // Get like count
        final likesSnapshot = await _firestore
            .collection('photos')
            .doc(photoId)
            .collection('likes')
            .get();
        final likesCount = likesSnapshot.docs.length;

        final timestamp = data['timestamp'] is Timestamp 
            ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
            : data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

        final photo = PhotoData(
          id: photoId,
          file: null,
          firebaseUrl: data['url'] ?? data['firebaseUrl'],
          thumbnailUrl: data['thumbnailUrl'],
          mediumUrl: data['mediumUrl'],
          fullUrl: data['fullUrl'],
          thumbnailUrlJPEG: data['thumbnailUrlJPEG'],
          mediumUrlJPEG: data['mediumUrlJPEG'],
          fullUrlJPEG: data['fullUrlJPEG'],
          title: data['title'] ?? 'Untitled',
          comment: data['comment'] ?? '',
          isLiked: isLiked,
          userId: userId,
          timestamp: timestamp,
          likesCount: likesCount,
        );
        photos.add(photo);
      }

      return photos;
    } catch (e) {
      print('❌ Error loading paginated photos: $e');
      return [];
    } finally {
      _isLoading = false;
    }
  }

  /// Check if there's more data to load
  static bool get hasMoreData => _hasMoreData;

  /// Reset pagination state
  static void resetPagination() {
    _lastDocument = null;
    _hasMoreData = true;
    _isLoading = false;
  }
}