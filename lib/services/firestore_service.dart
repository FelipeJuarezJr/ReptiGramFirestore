import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  static CollectionReference get users => _firestore.collection('users');
  static CollectionReference get usernames => _firestore.collection('usernames');
  static CollectionReference get posts => _firestore.collection('posts');
  static CollectionReference get photos => _firestore.collection('photos');
  static CollectionReference get binders => _firestore.collection('binders');
  static CollectionReference get albums => _firestore.collection('albums');
  static CollectionReference get notebooks => _firestore.collection('notebooks');
  static CollectionReference get likes => _firestore.collection('likes');
  static CollectionReference get comments => _firestore.collection('comments');

  // User operations
  static Future<void> createUser(UserModel user) async {
    await users.doc(user.uid).set(user.toJson());
  }

  static Future<void> reserveUsername(String username, String uid) async {
    await usernames.doc(username.toLowerCase()).set({'uid': uid});
  }

  static Future<bool> isUsernameAvailable(String username) async {
    final doc = await usernames.doc(username.toLowerCase()).get();
    return !doc.exists;
  }

  static Future<UserModel?> getUser(String uid) async {
    final doc = await users.doc(uid).get();
    if (doc.exists) {
      return UserModel.fromJson({...doc.data() as Map<String, dynamic>, 'uid': uid});
    }
    return null;
  }

  static Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    await users.doc(uid).update(updates);
  }

  static Future<void> updateLastLogin(String uid) async {
    await users.doc(uid).update({'lastLogin': FieldValue.serverTimestamp()});
  }

  // Post operations
  static Future<DocumentReference> createPost(Map<String, dynamic> postData) async {
    return await posts.add(postData);
  }

  static Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    await posts.doc(postId).update(updates);
  }

  static Future<void> deletePost(String postId) async {
    await posts.doc(postId).delete();
  }

  static Stream<QuerySnapshot> getPostsStream() {
    return posts.orderBy('timestamp', descending: true).snapshots();
  }

  static Future<QuerySnapshot> getPosts() async {
    return await posts.orderBy('timestamp', descending: true).get();
  }

  // Like operations
  static Future<void> likePost(String postId, String userId) async {
    await posts.doc(postId).collection('likes').doc(userId).set({
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> unlikePost(String postId, String userId) async {
    await posts.doc(postId).collection('likes').doc(userId).delete();
  }

  static Future<bool> isPostLiked(String postId, String userId) async {
    final doc = await posts.doc(postId).collection('likes').doc(userId).get();
    return doc.exists;
  }

  static Stream<QuerySnapshot> getPostLikesStream(String postId) {
    return posts.doc(postId).collection('likes').snapshots();
  }

  // Comment operations
  static Future<DocumentReference> addComment(String postId, Map<String, dynamic> commentData) async {
    return await posts.doc(postId).collection('comments').add(commentData);
  }

  static Stream<QuerySnapshot> getPostCommentsStream(String postId) {
    return posts.doc(postId).collection('comments').orderBy('timestamp', descending: false).snapshots();
  }

  // Photo operations
  static Future<DocumentReference> createPhoto(Map<String, dynamic> photoData) async {
    return await photos.add(photoData);
  }

  static Future<void> updatePhoto(String photoId, Map<String, dynamic> updates) async {
    await photos.doc(photoId).update(updates);
  }

  static Future<void> deletePhoto(String photoId) async {
    await photos.doc(photoId).delete();
  }

  static Stream<QuerySnapshot> getPhotosStream() {
    return photos.orderBy('timestamp', descending: true).snapshots();
  }

  static Future<QuerySnapshot> getPhotos() async {
    return await photos.orderBy('timestamp', descending: true).get();
  }

  // Binder operations
  static Future<DocumentReference> createBinder(Map<String, dynamic> binderData) async {
    return await binders.add(binderData);
  }

  static Future<void> updateBinder(String binderId, Map<String, dynamic> updates) async {
    await binders.doc(binderId).update(updates);
  }

  static Future<void> deleteBinder(String binderId) async {
    await binders.doc(binderId).delete();
  }

  static Stream<QuerySnapshot> getBindersStream() {
    return binders.orderBy('createdAt', descending: true).snapshots();
  }

  static Future<QuerySnapshot> getBinders() async {
    return await binders.orderBy('createdAt', descending: true).get();
  }

  // Album operations
  static Future<DocumentReference> createAlbum(Map<String, dynamic> albumData) async {
    return await albums.add(albumData);
  }

  static Future<void> updateAlbum(String albumId, Map<String, dynamic> updates) async {
    await albums.doc(albumId).update(updates);
  }

  static Future<void> deleteAlbum(String albumId) async {
    await albums.doc(albumId).delete();
  }

  static Stream<QuerySnapshot> getAlbumsStream() {
    return albums.orderBy('createdAt', descending: true).snapshots();
  }

  static Future<QuerySnapshot> getAlbums() async {
    return await albums.orderBy('createdAt', descending: true).get();
  }

  // Notebook operations
  static Future<DocumentReference> createNotebook(Map<String, dynamic> notebookData) async {
    return await notebooks.add(notebookData);
  }

  static Future<void> updateNotebook(String notebookId, Map<String, dynamic> updates) async {
    await notebooks.doc(notebookId).update(updates);
  }

  static Future<void> deleteNotebook(String notebookId) async {
    await notebooks.doc(notebookId).delete();
  }

  static Stream<QuerySnapshot> getNotebooksStream() {
    return notebooks.orderBy('timestamp', descending: true).snapshots();
  }

  static Future<QuerySnapshot> getNotebooks() async {
    return await notebooks.orderBy('timestamp', descending: true).get();
  }

  // Utility methods
  static FieldValue get serverTimestamp => FieldValue.serverTimestamp();

  static Future<String?> getUsernameById(String userId) async {
    final doc = await users.doc(userId).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['username'] as String?;
    }
    return null;
  }

  // Batch operations for better performance
  static Future<void> batchCreateUserAndReserveUsername(UserModel user) async {
    final batch = _firestore.batch();
    
    batch.set(users.doc(user.uid), user.toJson());
    batch.set(usernames.doc(user.username.toLowerCase()), {'uid': user.uid});
    
    await batch.commit();
  }

  // Update username in batch operation
  static Future<void> updateUsername(String userId, String oldUsername, String newUsername) async {
    final batch = _firestore.batch();
    
    // Update user document
    batch.update(users.doc(userId), {'username': newUsername});
    
    // Remove old username reservation
    if (oldUsername.isNotEmpty) {
      batch.delete(usernames.doc(oldUsername.toLowerCase()));
    }
    
    // Add new username reservation
    batch.set(usernames.doc(newUsername.toLowerCase()), {'uid': userId});
    
    await batch.commit();
  }

  static Future<String?> getUserPhotoUrl(String uid) async {
    final doc = await users.doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['photoUrl'] ?? data['photoURL'];
    }
    return null;
  }

  static Future<void> saveFcmToken(String uid, String token) async {
    await users.doc(uid).update({
      'fcmToken': token,
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    });
  }

  static Future<String?> getFcmToken(String uid) async {
    final doc = await users.doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['fcmToken'] as String?;
    }
    return null;
  }

  static Future<void> uploadUserPhoto(String uid, Uint8List imageBytes) async {
    try {
      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('$uid.jpg');
      
      await storageRef.putData(imageBytes);
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Update user document with photo URL
      await users.doc(uid).update({
        'photoUrl': downloadUrl,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error uploading user photo: $e');
      rethrow;
    }
  }
} 