import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ... existing reptile and breeding related methods ...

  Future<void> addPost({
    required String userId,
    required String content,
    String? mediaUrl,
  }) async {
    await _db.collection('posts').add({
      'user_id': userId,
      'content': content,
      'media_url': mediaUrl ?? '',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    await _db.collection('comments').add({
      'post_id': postId,
      'user_id': userId,
      'content': content,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
} 