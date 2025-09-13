import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LikeCacheService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Update cached like data in photo document when a like is toggled
  static Future<void> updatePhotoLikeCache({
    required String photoId,
    required String userId,
    required bool isLiked,
  }) async {
    try {
      final photoRef = _firestore.collection('photos').doc(photoId);
      
      if (isLiked) {
        // Add like to cache
        await photoRef.update({
          'likesCount': FieldValue.increment(1),
          'recentLikers': FieldValue.arrayUnion([userId]),
          'likesMap.$userId': true,
        });
      } else {
        // Remove like from cache
        await photoRef.update({
          'likesCount': FieldValue.increment(-1),
          'recentLikers': FieldValue.arrayRemove([userId]),
          'likesMap.$userId': FieldValue.delete(),
        });
      }
      
      print('✅ Updated like cache for photo $photoId: ${isLiked ? 'liked' : 'unliked'}');
    } catch (e) {
      print('❌ Error updating like cache: $e');
      rethrow;
    }
  }

  /// Get cached like data from photo document
  static Map<String, dynamic> getCachedLikeData(Map<String, dynamic> photoData, String currentUserId) {
    final likesCount = photoData['likesCount'] as int? ?? 0;
    final recentLikers = (photoData['recentLikers'] as List<dynamic>?)?.cast<String>() ?? [];
    final likesMap = Map<String, bool>.from(photoData['likesMap'] as Map<String, dynamic>? ?? {});
    
    // Check if current user liked this photo
    final isLiked = likesMap[currentUserId] ?? false;
    
    return {
      'likesCount': likesCount,
      'isLiked': isLiked,
      'recentLikers': recentLikers,
      'likesMap': likesMap,
    };
  }

  /// Migrate existing photos to include like cache fields (one-time migration)
  static Future<void> migratePhotosToLikeCache() async {
    try {
      print('🔄 Starting migration of photos to include like cache...');
      
      final photosSnapshot = await _firestore.collection('photos').get();
      int migratedCount = 0;
      
      for (var doc in photosSnapshot.docs) {
        final data = doc.data();
        
        // Skip if already has like cache fields
        if (data.containsKey('recentLikers') && data.containsKey('likesMap')) {
          continue;
        }
        
        // Get current like count from likes collection
        final likesSnapshot = await _firestore
            .collection('likes')
            .where('photoId', isEqualTo: doc.id)
            .get();
        
        final likesCount = likesSnapshot.docs.length;
        final likerIds = likesSnapshot.docs
            .map((likeDoc) => likeDoc.data()['userId'] as String)
            .toList();
        
        // Create likes map
        final likesMap = <String, bool>{};
        for (final likerId in likerIds) {
          likesMap[likerId] = true;
        }
        
        // Update photo document with cached like data
        await doc.reference.update({
          'likesCount': likesCount,
          'recentLikers': likerIds.take(5).toList(), // Keep only last 5 likers
          'likesMap': likesMap,
        });
        
        migratedCount++;
        
        if (migratedCount % 10 == 0) {
          print('📊 Migrated $migratedCount photos...');
        }
      }
      
      print('✅ Migration complete! Migrated $migratedCount photos to like cache');
    } catch (e) {
      print('❌ Error during migration: $e');
      rethrow;
    }
  }
}
