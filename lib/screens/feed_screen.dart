import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import '../models/photo_data.dart';
import '../state/app_state.dart';
import '../services/firestore_service.dart';

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
      
      // Firestore: Get all photos
      final photosQuery = await FirestoreService.photos.get();
      
      // Firestore: Get all likes
      final likesQuery = await FirestoreService.likes.get();

      final List<PhotoData> allPhotos = [];
      
      // Convert likes to Map for faster lookups
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

      for (var doc in photosQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final photoId = doc.id;
        final userId = data['userId'] as String?;
        
        if (userId == null) continue;
        
        final photoLikes = likesMap[photoId] ?? {};
        final isLiked = currentUser != null && photoLikes[currentUser.uid] == true;

        // Handle timestamp
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

      print('Total photos: ${allPhotos.length}');
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
                    )
                  : const Center(
                      child: Icon(Icons.image),
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

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postComment(String content) async {
    final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    if (content.trim().isEmpty) return;

    try {
      // Firestore: Add comment
      await FirestoreService.comments.add({
        'photoId': widget.photo.id,
        'userId': currentUser.uid,
        'content': content.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      
      // Scroll to top after posting
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
            height: MediaQuery.of(context).size.height * 0.3,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService.comments
                        .where('photoId', isEqualTo: widget.photo.id)
                        .orderBy('timestamp', descending: true)
                        .limit(100)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No comments yet'));
                      }

                      final commentsList = snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return {
                          'userId': data['userId'] as String,
                          'content': data['content'] as String,
                          'timestamp': data['timestamp'] is Timestamp 
                              ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
                              : data['timestamp'] as int,
                        };
                      }).toList();

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.only(bottom: 8),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: commentsList.length,
                        itemBuilder: (context, index) {
                          final comment = commentsList[index];
                          return FutureBuilder<String?>(
                            future: Provider.of<AppState>(context, listen: false)
                                .fetchUsername(comment['userId'] as String),
                            builder: (context, usernameSnapshot) {
                              return ListTile(
                                title: Text(
                                  '${usernameSnapshot.data ?? 'Loading...'}: ${comment['content']}',
                                  style: const TextStyle(color: Colors.brown),
                                ),
                                subtitle: Text(
                                  _formatTimestamp(comment['timestamp'] as int),
                                  style: TextStyle(color: Colors.brown[400]),
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
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _postComment,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () => _postComment(_commentController.text),
                        color: Theme.of(context).primaryColor,
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