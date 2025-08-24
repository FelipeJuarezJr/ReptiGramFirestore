import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';

class FollowService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Follow a user
  static Future<void> followUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final currentUserId = currentUser.uid;
    
    // Use batch write for atomicity
    final batch = _firestore.batch();
    
    // Add to current user's following collection
    final followingRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);
    
    batch.set(followingRef, {
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Add to target user's followers collection
    final followersRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);
    
    batch.set(followersRef, {
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Update follow counts
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    
    batch.update(currentUserRef, {
      'followingCount': FieldValue.increment(1),
    });
    
    batch.update(targetUserRef, {
      'followersCount': FieldValue.increment(1),
    });
    
    await batch.commit();
  }

  // Unfollow a user
  static Future<void> unfollowUser(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    final currentUserId = currentUser.uid;
    
    // Use batch write for atomicity
    final batch = _firestore.batch();
    
    // Remove from current user's following collection
    final followingRef = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('following')
        .doc(targetUserId);
    
    batch.delete(followingRef);
    
    // Remove from target user's followers collection
    final followersRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUserId);
    
    batch.delete(followersRef);
    
    // Update follow counts
    final currentUserRef = _firestore.collection('users').doc(currentUserId);
    final targetUserRef = _firestore.collection('users').doc(targetUserId);
    
    batch.update(currentUserRef, {
      'followingCount': FieldValue.increment(-1),
    });
    
    batch.update(targetUserRef, {
      'followersCount': FieldValue.increment(-1),
    });
    
    await batch.commit();
  }

  // Check if current user follows target user
  static Future<bool> isFollowing(String targetUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    final doc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .doc(targetUserId)
        .get();
    
    return doc.exists;
  }

  // Get list of users that current user follows
  static Stream<List<String>> getFollowingStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Get list of users following current user
  static Stream<List<String>> getFollowersStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('followers')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  // Get user's timeline (posts from followed users)
  static Stream<List<PostModel>> getUserTimelineStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(<PostModel>[]);

    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('timeline')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return PostModel.fromDoc(data, doc.id);
        }).toList());
  }

  // Get user's own posts
  static Stream<List<PostModel>> getUserPostsStream(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          return PostModel(
            id: doc.id,
            userId: data['userId'] ?? '',
            content: data['content'] ?? '',
            timestamp: (data['timestamp'] as Timestamp).toDate(),
            imageUrl: data['imageUrl'],
            isLiked: data['isLiked'] ?? false,
            likeCount: data['likeCount'] ?? 0,
            comments: [], // Comments will be loaded separately if needed
          );
        }).toList());
  }

  // Get follow counts for a user
  static Future<Map<String, int>> getFollowCounts(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return {'followers': 0, 'following': 0};
    
    final data = doc.data() as Map<String, dynamic>;
    return {
      'followers': data['followersCount'] ?? 0,
      'following': data['followingCount'] ?? 0,
    };
  }

  // Get users list for follow suggestions (users not followed by current user)
  static Future<List<UserModel>> getFollowSuggestions({int limit = 10}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    // Get current user's following list
    final followingSnapshot = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('following')
        .get();
    
    final followingIds = followingSnapshot.docs.map((doc) => doc.id).toSet();
    followingIds.add(currentUser.uid); // Exclude self

    // Get users not in following list
    final usersSnapshot = await _firestore
        .collection('users')
        .limit(limit + followingIds.length) // Get more to account for exclusions
        .get();

    final suggestions = <UserModel>[];
    for (var doc in usersSnapshot.docs) {
      if (!followingIds.contains(doc.id)) {
        final data = doc.data();
        suggestions.add(UserModel.fromJson({...data, 'uid': doc.id}));
        if (suggestions.length >= limit) break;
      }
    }

    return suggestions;
  }
}
