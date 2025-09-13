import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';

class PaginatedPostsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const int _pageSize = 10;
  static DocumentSnapshot? _lastDocument;
  static bool _hasMoreData = true;
  static bool _isLoading = false;

  /// Load posts with pagination
  static Future<List<PostModel>> loadPosts({
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
          .collection('posts')
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

      final posts = <PostModel>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final postId = doc.id;
        
        // Get like status
        final likeDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(userId)
            .get();
        final isLiked = likeDoc.exists;

        // Get like count
        final likesSnapshot = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .get();
        final likesCount = likesSnapshot.docs.length;

        final timestamp = data['timestamp'] is Timestamp 
            ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
            : data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

        final post = PostModel(
          id: postId,
          userId: data['userId'] ?? userId,
          content: data['content'] ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
          title: data['title'] ?? 'Untitled Post',
          authorName: data['authorName'] ?? 'Unknown',
          likesCount: likesCount,
          isLiked: isLiked,
          imageUrl: data['imageUrl'],
        );
        posts.add(post);
      }

      return posts;
    } catch (e) {
      print('❌ Error loading paginated posts: $e');
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