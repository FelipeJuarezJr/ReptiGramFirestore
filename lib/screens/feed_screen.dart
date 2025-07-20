import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import '../models/photo_data.dart';
import '../state/app_state.dart';
import '../services/firestore_service.dart';
import 'dart:typed_data';

class FeedScreen extends StatefulWidget {
  final bool showLikedOnly;
  
  const FeedScreen({
    super.key,
    this.showLikedOnly = false,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<PhotoData> _photos = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedCommentImage; // For comment image upload

  @override
  void initState() {
    super.initState();
    print('FeedScreen initialized with showLikedOnly: ${widget.showLikedOnly}');
    Future.microtask(() async {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.initializeUser(); // Make sure user is initialized
      if (mounted) {
        await _loadPhotos();
      }
    });
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showLikedOnly != widget.showLikedOnly) {
      print('Feed type changed, reloading photos');
      _loadPhotos();
    }
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    print('Loading photos with showLikedOnly: ${widget.showLikedOnly}');

    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      print('Current user: ${currentUser?.uid}');
      
      // First, get all photos from Firestore
      final photosQuery = await FirestoreService.photos.get();
      print('Found ${photosQuery.docs.length} photos in Firestore');
      
      // Create a map of existing Firestore photos
      final firestorePhotos = <String, Map<String, dynamic>>{};
      for (var doc in photosQuery.docs) {
        firestorePhotos[doc.id] = doc.data() as Map<String, dynamic>;
      }
      
      // Get all likes from Firestore
      final likesQuery = await FirestoreService.likes.get();
      final likesMap = <String, Map<String, bool>>{};
      for (var doc in likesQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final photoId = data['photoId'] as String?;
        final userId = data['userId'] as String?;
        if (photoId != null && userId != null) {
          likesMap[photoId] ??= {};
          likesMap[photoId]![userId] = true;
        }
      }

      final List<PhotoData> allPhotos = [];
      
      // Scan Firebase Storage for all images
      print('Scanning Firebase Storage for all images...');
      await _scanStorageForImages(allPhotos, firestorePhotos, likesMap, currentUser);
      
      // Add Firestore photos that might not be in Storage
      for (var entry in firestorePhotos.entries) {
        final photoId = entry.key;
        final data = entry.value;
        final userId = data['userId'] as String?;
        
        if (userId == null) continue;
        
        // Check if this photo is already added from Storage scan
        final alreadyAdded = allPhotos.any((photo) => photo.id == photoId);
        if (alreadyAdded) continue;
        
        print('Adding Firestore-only photo: $photoId from user $userId');
        
        final photoLikes = likesMap[photoId] ?? {};
        final isLiked = currentUser != null && photoLikes[currentUser.uid] == true;

        final timestamp = data['timestamp'] is Timestamp 
            ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
            : data['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

        final photo = PhotoData(
          id: photoId,
          file: null,
          firebaseUrl: data['url'] ?? data['firebaseUrl'],
          title: data['title'] ?? 'Untitled',
          comment: data['comment'] ?? '',
          isLiked: isLiked,
          userId: userId,
          timestamp: timestamp,
          likesCount: photoLikes.length,
        );
        allPhotos.add(photo);
      }

      // Sort by timestamp (newest first)
      allPhotos.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

      // Filter liked photos if needed
      final filteredPhotos = widget.showLikedOnly 
          ? allPhotos.where((photo) => photo.isLiked).toList()
          : allPhotos;

      print('Total photos found: ${allPhotos.length}');
      print('Filtered photos: ${filteredPhotos.length}');
      print('Show liked only: ${widget.showLikedOnly}');

      if (mounted) {
        setState(() {
          _photos = filteredPhotos;
          _isLoading = false;
        });

        // Show message if no liked photos and user is logged in
        if (widget.showLikedOnly && filteredPhotos.isEmpty && currentUser != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You haven\'t liked any photos yet'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading photos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _scanStorageForImages(
    List<PhotoData> allPhotos,
    Map<String, Map<String, dynamic>> firestorePhotos,
    Map<String, Map<String, bool>> likesMap,
    dynamic currentUser,
  ) async {
    try {
      final storage = FirebaseStorage.instance;
      
      // Scan the photos folder
      print('Scanning storage path: photos');
      
      try {
        final photosRef = storage.ref().child('photos');
        final result = await photosRef.listAll();
        
        print('Found ${result.items.length} items in photos folder');
        
        // Process every item in the photos folder as a photo
        for (final item in result.items) {
          print('Processing item in photos/: ${item.name}');
          await _processStorageImage(
            item,
            allPhotos,
            firestorePhotos,
            likesMap,
            currentUser,
            'photos',
          );
        }
      } catch (e) {
        print('Error scanning photos folder: $e');
        // Fallback: try to access known user folders
        await _tryAccessKnownUserFolders(allPhotos, firestorePhotos, likesMap, currentUser);
      }
      
      // Also scan users folder if it exists
      try {
        print('Scanning storage path: users');
        final usersRef = storage.ref().child('users');
        final usersResult = await usersRef.listAll();
        
        for (final userFolder in usersResult.items) {
          if (!userFolder.name.contains('.')) {
            try {
              final userPhotosRef = userFolder.child('photos');
              final userPhotosResult = await userPhotosRef.listAll();
              
              for (final photoItem in userPhotosResult.items) {
                await _processStorageImage(
                  photoItem,
                  allPhotos,
                  firestorePhotos,
                  likesMap,
                  currentUser,
                  'users/${userFolder.name}/photos',
                );
              }
            } catch (e) {
              print('Error scanning users/${userFolder.name}/photos: $e');
            }
          }
        }
      } catch (e) {
        print('Error scanning users folder: $e');
      }
      
    } catch (e) {
      print('Error scanning storage: $e');
    }
  }

  Future<void> _tryAccessUserFolder(
    Reference userFolder,
    List<PhotoData> allPhotos,
    Map<String, Map<String, dynamic>> firestorePhotos,
    Map<String, Map<String, bool>> likesMap,
    dynamic currentUser,
    String basePath,
  ) async {
    try {
      // Try to access common photo file extensions
      final extensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      final userId = userFolder.name;
      
      for (final ext in extensions) {
        try {
          // Try to find photos with this extension
          final photoRef = userFolder.child('photo.$ext');
          await _processStorageImage(
            photoRef,
            allPhotos,
            firestorePhotos,
            likesMap,
            currentUser,
            '$basePath/$userId',
          );
        } catch (e) {
          // Continue to next extension
        }
      }
    } catch (e) {
      print('Error accessing user folder ${userFolder.name}: $e');
    }
  }

  Future<void> _tryAccessKnownUserFolders(
    List<PhotoData> allPhotos,
    Map<String, Map<String, dynamic>> firestorePhotos,
    Map<String, Map<String, bool>> likesMap,
    dynamic currentUser,
  ) async {
    // Try to access photos from known user IDs in Firestore
    final knownUserIds = <String>{};
    for (final entry in firestorePhotos.entries) {
      final userId = entry.value['userId'] as String?;
      if (userId != null) {
        knownUserIds.add(userId);
      }
    }
    
    for (final userId in knownUserIds) {
      try {
        final userPhotosRef = FirebaseStorage.instance.ref().child('photos').child(userId);
        final result = await userPhotosRef.listAll();
        
        for (final photoItem in result.items) {
          await _processStorageImage(
            photoItem,
            allPhotos,
            firestorePhotos,
            likesMap,
            currentUser,
            'photos/$userId',
          );
        }
      } catch (e) {
        print('Error accessing known user folder $userId: $e');
      }
    }
  }

  Future<void> _processStorageImage(
    Reference photoRef,
    List<PhotoData> allPhotos,
    Map<String, Map<String, dynamic>> firestorePhotos,
    Map<String, Map<String, bool>> likesMap,
    dynamic currentUser,
    String basePath,
  ) async {
    try {
      // Extract photo ID and user ID from the path
      final pathParts = photoRef.fullPath.split('/');
      String photoId = 'unknown'; // Initialize with default value
      String userId = 'unknown';
      
      print('Processing image at path: ${photoRef.fullPath}');
      
      if (pathParts.length >= 2 && pathParts[0] == 'photos') {
        if (pathParts.length == 2) {
          // Format: photos/{photoId} (direct photo)
          photoId = pathParts[1];
          // Try to extract user ID from photoId if it contains a UUID or timestamp
          if (photoId.contains('_')) {
            final parts = photoId.split('_');
            if (parts.length >= 2 && parts[1].length > 20) {
              // This might be a UUID, try to find user from Firestore
              final firestoreData = firestorePhotos[photoId];
              userId = firestoreData?['userId'] ?? 'unknown';
            }
          }
        } else if (pathParts.length >= 4) {
          // Format: photos/{userId}/{photoId}
          userId = pathParts[2];
          photoId = pathParts[3];
        }
      } else if (pathParts.length >= 5 && pathParts[0] == 'users') {
        // Format: users/{userId}/photos/{photoId}
        userId = pathParts[1];
        photoId = pathParts[4];
      } else {
        // Fallback: use the last part as photoId
        photoId = pathParts.last;
      }
      
      // Remove file extension from photoId
      photoId = photoId.split('.').first;
      
      // Check if this photo is already added
      if (allPhotos.any((photo) => photo.id == photoId)) {
        print('Photo $photoId already added, skipping');
        return;
      }
      
      print('Found storage image: $photoId from user $userId at path: ${photoRef.fullPath}');
      
      // Get download URL
      final downloadUrl = await photoRef.getDownloadURL();
      
      // Get Firestore data if available
      final firestoreData = firestorePhotos[photoId];
      final photoLikes = likesMap[photoId] ?? {};
      final isLiked = currentUser != null && photoLikes[currentUser.uid] == true;
      
      // Extract timestamp from photoId if it's a timestamp
      int timestamp;
      if (RegExp(r'^\d+$').hasMatch(photoId)) {
        timestamp = int.tryParse(photoId) ?? DateTime.now().millisecondsSinceEpoch;
      } else {
        timestamp = firestoreData?['timestamp'] is Timestamp 
            ? (firestoreData!['timestamp'] as Timestamp).millisecondsSinceEpoch
            : firestoreData?['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      }
      
      final photo = PhotoData(
        id: photoId,
        file: null,
        firebaseUrl: downloadUrl,
        title: firestoreData?['title'] ?? 'Photo',
        comment: firestoreData?['comment'] ?? '',
        isLiked: isLiked,
        userId: firestoreData?['userId'] ?? userId,
        timestamp: timestamp,
        likesCount: photoLikes.length,
      );
      
      allPhotos.add(photo);
      print('Added storage photo: $photoId');
      
    } catch (e) {
      print('Error processing storage image ${photoRef.fullPath}: $e');
    }
  }

  void _showFullScreenImage(PhotoData photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenPhotoView(
          photo: photo,
          onLikeToggled: _toggleLike,
        ),
      ),
    );
  }

  Widget _buildGridItem(PhotoData photo) {
    final appState = Provider.of<AppState>(context, listen: false);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      color: Colors.white.withOpacity(0.9),
      child: InkWell(
        onTap: () => _showFullScreenImage(photo),
        borderRadius: BorderRadius.circular(15.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo as background
            ClipRRect(
              borderRadius: BorderRadius.circular(15.0),
              child: photo.firebaseUrl != null
                  ? Image.network(
                      photo.firebaseUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 32,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: 32,
                        ),
                      ),
                    ),
            ),
            // Username overlay at the top
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<String?>(
                  future: appState.fetchUsername(photo.userId ?? ''),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? 'Loading...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
            ),
            // Like button overlay at the top right
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${photo.likesCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please log in to like photos')),
                          );
                          return;
                        }
                        _toggleLike(photo);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          photo.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: photo.isLiked ? Colors.red : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Comments overlay at the bottom
            Positioned(
              bottom: 4,
              left: 4,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.comments
                    .where('photoId', isEqualTo: photo.id)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  final commentCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  final comments = snapshot.hasData ? snapshot.data!.docs : <QueryDocumentSnapshot>[];
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.comment,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$commentCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(PhotoData photo) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final currentUser = appState.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like photos')),
      );
      return;
    }

    try {
      // Optimistic update
      setState(() {
        photo.isLiked = !photo.isLiked;
        photo.likesCount += photo.isLiked ? 1 : -1;
      });

      // Firestore: Toggle like
      if (photo.isLiked) {
        await FirestoreService.likes.add({
          'photoId': photo.id,
          'userId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Find and delete the like document
        final likeQuery = await FirestoreService.likes
            .where('photoId', isEqualTo: photo.id)
            .where('userId', isEqualTo: currentUser.uid)
            .get();
        
        for (var doc in likeQuery.docs) {
          await doc.reference.delete();
        }
      }

      // If we're in "Liked Only" view and the photo was unliked, remove it from the list
      if (widget.showLikedOnly && !photo.isLiked) {
        setState(() {
          _photos.removeWhere((p) => p.id == photo.id);
        });
      }

    } catch (e) {
      // Revert on error
      setState(() {
        photo.isLiked = !photo.isLiked;
        photo.likesCount += photo.isLiked ? 1 : -1;
      });
      print('Error toggling like: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
    
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const TitleHeader(),
              const Header(initialIndex: 2),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : widget.showLikedOnly && currentUser == null
                        ? const Center(
                            child: Text(
                              'Please log in to view liked photos',
                              style: TextStyle(
                                color: AppColors.titleText,
                                fontSize: 18,
                              ),
                            ),
                          )
                        : _photos.isEmpty
                            ? Center(
                                child: Text(
                                  widget.showLikedOnly 
                                      ? 'No liked photos yet'
                                      : 'No photos available',
                                  style: const TextStyle(
                                    color: AppColors.titleText,
                                    fontSize: 18,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadPhotos,
                                child: GridView.builder(
                                  padding: const EdgeInsets.all(8.0),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8.0,
                                    mainAxisSpacing: 8.0,
                                  ),
                                  itemCount: _photos.length,
                                  itemBuilder: (context, index) => _buildGridItem(_photos[index]),
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenPhotoView extends StatefulWidget {
  final PhotoData photo;
  final Function(PhotoData) onLikeToggled;

  const FullScreenPhotoView({
    super.key,
    required this.photo,
    required this.onLikeToggled,
  });

  @override
  State<FullScreenPhotoView> createState() => _FullScreenPhotoViewState();
}

class _FullScreenPhotoViewState extends State<FullScreenPhotoView> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, String?> _avatarUrls = {}; // Cache for avatar URLs
  XFile? _selectedCommentImage; // For comment image upload

  @override
  void initState() {
    super.initState();
    // Scroll to bottom after the widget is built to show newest comments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _getAvatarUrl(String userId) async {
    if (_avatarUrls.containsKey(userId)) {
      return _avatarUrls[userId];
    }
    
    try {
      // Get photo URL from Firestore (includes both custom uploads and Google profile URLs)
      final url = await FirestoreService.getUserPhotoUrl(userId);
      
      if (mounted) {
        setState(() {
          _avatarUrls[userId] = url;
        });
      }
      return url;
    } catch (e) {
      print('Error fetching avatar for user $userId: $e');
      return null;
    }
  }

  Widget _buildUserAvatar(String userId) {
    return FutureBuilder<String?>(
      future: _getAvatarUrl(userId),
      builder: (context, snapshot) {
        final avatarUrl = snapshot.data;
        
        if (avatarUrl == null || avatarUrl.isEmpty) {
          // Show app logo as fallback for no avatar
          return CircleAvatar(
            radius: 16,
            backgroundImage: const AssetImage('assets/img/reptiGramLogo.png'),
          );
        }

        // Show network image with proper error handling
        return CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(avatarUrl),
          onBackgroundImageError: (exception, stackTrace) {
            // Handle image loading errors by showing app logo
            print('Feed avatar image failed to load: $avatarUrl, error: $exception');
            if (mounted) {
              setState(() {
                _avatarUrls[userId] = null;
              });
            }
          },
        );
      },
    );
  }

  Future<void> _postComment(String content) async {
    print('Posting comment: $content');
    final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    if (content.trim().isEmpty && _selectedCommentImage == null) return;

    try {
      print('Adding comment to Firestore for photo: ${widget.photo.id}');
      
      String? imageUrl;
      
      // Upload image if provided
      if (_selectedCommentImage != null) {
        try {
          final String commentImageId = DateTime.now().millisecondsSinceEpoch.toString();
          final Reference ref = FirebaseStorage.instance
              .ref()
              .child('comment_images')
              .child(currentUser.uid)
              .child(commentImageId);
          
          if (kIsWeb) {
            final bytes = await _selectedCommentImage!.readAsBytes();
            await ref.putData(
              bytes,
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'userId': currentUser.uid,
                  'uploadedAt': DateTime.now().toString(),
                },
              ),
            );
          } else {
            await ref.putFile(
              File(_selectedCommentImage!.path),
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'userId': currentUser.uid,
                  'uploadedAt': DateTime.now().toString(),
                },
              ),
            );
          }
          
          imageUrl = await ref.getDownloadURL();
        } catch (e) {
          print('Error uploading comment image: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload image: ${e.toString()}')),
          );
          return;
        }
      }
      
      // Firestore: Add comment
      final docRef = await FirestoreService.comments.add({
        'photoId': widget.photo.id,
        'userId': currentUser.uid,
        'content': content.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      });
      print('Comment added successfully with ID: ${docRef.id}');

      _commentController.clear();
      setState(() {
        _selectedCommentImage = null;
      });
      
      // Scroll to bottom to show the new comment - only if controller is attached
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error posting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Likes count
                Row(
                  children: [
                    Text(
                      '${widget.photo.likesCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please log in to like photos')),
                          );
                          return;
                        }
                        widget.onLikeToggled(widget.photo);
                        setState(() {}); // Refresh UI after toggle
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          widget.photo.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: widget.photo.isLiked ? Colors.red : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Comments count
                StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.comments
                      .where('photoId', isEqualTo: widget.photo.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final commentCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return Row(
                      children: [
                        Text(
                          '$commentCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.comment,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Image viewer
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: widget.photo.id,
                  child: widget.photo.firebaseUrl != null
                      ? Image.network(
                          widget.photo.firebaseUrl!,
                          fit: BoxFit.contain,
                        )
                      : const Icon(Icons.image, size: 100, color: Colors.white),
                ),
              ),
            ),
          ),
          // Comments section
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Comments header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.comment, color: Colors.brown),
                      const SizedBox(width: 8),
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService.comments
                        .where('photoId', isEqualTo: widget.photo.id)
                        .limit(100)
                        .snapshots(),
                    builder: (context, snapshot) {
                      print('Comments snapshot: ${snapshot.hasData}');
                      if (snapshot.hasData) {
                        print('Comments count: ${snapshot.data!.docs.length}');
                        print('Snapshot connection state: ${snapshot.connectionState}');
                        for (var doc in snapshot.data!.docs) {
                          print('Comment data: ${doc.data()}');
                        }
                      }
                      
                      // Show loading while waiting for data
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      // Show error if there's an error
                      if (snapshot.hasError) {
                        print('Comments error: ${snapshot.error}');
                        return Center(
                          child: Text(
                            'Error loading comments: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }
                      
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        print('No comments to display!');
                        return const Center(
                          child: Text(
                            'No comments yet',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        );
                      }

                      final commentsList = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        print('Processing comment: $data');
                        
                        // Handle timestamp more robustly
                        int timestamp;
                        if (data['timestamp'] is Timestamp) {
                          timestamp = (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
                        } else if (data['timestamp'] is int) {
                          timestamp = data['timestamp'] as int;
                        } else {
                          timestamp = DateTime.now().millisecondsSinceEpoch;
                        }
                        
                        return {
                          'userId': data['userId'] as String? ?? 'unknown',
                          'content': data['content'] as String? ?? '',
                          'timestamp': timestamp,
                          'imageUrl': data['imageUrl'] as String?,
                        };
                      }).toList()
                        ..sort((a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int)); // Sort oldest first

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 8),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: commentsList.length,
                        itemBuilder: (context, index) {
                          final comment = commentsList[index];
                          return FutureBuilder<String?>(
                            future: Provider.of<AppState>(context, listen: false)
                                .fetchUsername(comment['userId'] as String),
                            builder: (context, usernameSnapshot) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildUserAvatar(comment['userId'] as String),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                usernameSnapshot.data ?? 'Loading...',
                                                style: const TextStyle(
                                                  color: Colors.brown,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                _formatTimestamp(comment['timestamp'] as int),
                                                style: TextStyle(
                                                  color: Colors.brown[400],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            comment['content'] as String,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 14,
                                            ),
                                          ),
                                          // Show image if comment has one
                                          if (comment['imageUrl'] != null) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              height: 120,
                                              width: 120,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.grey[300]!),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  comment['imageUrl'] as String,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey[200],
                                                      child: const Icon(
                                                        Icons.error,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                // Comment input
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Image preview
                      if (_selectedCommentImage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb
                                    ? FutureBuilder<Uint8List>(
                                        future: _selectedCommentImage!.readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData) {
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                              width: 120,
                                              height: 120,
                                            );
                                          } else {
                                            return const Center(
                                              child: CircularProgressIndicator(),
                                            );
                                          }
                                        },
                                      )
                                    : Image.file(
                                        File(_selectedCommentImage!.path),
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                      ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCommentImage = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.image, color: Colors.brown),
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 85,
                                maxWidth: 1024,
                                maxHeight: 1024,
                              );
                              if (image != null) {
                                setState(() {
                                  _selectedCommentImage = image;
                                });
                              }
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: const InputDecoration(
                                hintText: 'Add a comment...',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (text) => _postComment(text),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () => _postComment(_commentController.text),
                            color: Theme.of(context).primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}