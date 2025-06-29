import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import '../models/photo_data.dart';
import '../state/app_state.dart';

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
      
      // Get all photos from users
      final usersSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .get();

      // Get all likes in one call
      final likesSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('posts')
          .get();

      if (!usersSnapshot.exists) return;

      final List<PhotoData> allPhotos = [];
      final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
      
      // Convert likes snapshot to Map for faster lookups
      final likesData = (likesSnapshot.value as Map<dynamic, dynamic>?) ?? {};

      for (var entry in usersData.entries) {
        final userId = entry.key as String;
        final userData = entry.value as Map<dynamic, dynamic>;

        if (userData['photos'] != null) {
          final photos = userData['photos'] as Map<dynamic, dynamic>;
          photos.forEach((photoId, photoData) {
            final photoLikes = (likesData[photoId]?['likes'] as Map<dynamic, dynamic>?) ?? {};
            final isLiked = currentUser != null && photoLikes[currentUser.uid] == true;

            // Make sure we get the correct timestamp
            final timestamp = photoData['timestamp'] is int 
                ? photoData['timestamp'] as int
                : (photoData['timestamp'] as Map<dynamic, dynamic>?)?.values.first as int? 
                ?? DateTime.now().millisecondsSinceEpoch;

            final photo = PhotoData(
              id: photoId.toString(),
              file: null,
              firebaseUrl: photoData['firebaseUrl'] ?? photoData['url'],
              title: photoData['title'] ?? 'Untitled',
              comment: photoData['comment'] ?? '',
              isLiked: isLiked,
              userId: userId,
              timestamp: timestamp,
              likesCount: photoLikes.length,
            );
            allPhotos.add(photo);
          });
        }
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

      // Use the same path structure as post_screen.dart
      final likesRef = FirebaseDatabase.instance
          .ref()
          .child('posts')  // Changed from 'users'
          .child(photo.id)  // Use photo.id directly
          .child('likes')
          .child(currentUser.uid);

      if (photo.isLiked) {
        await likesRef.set(true);
      } else {
        await likesRef.remove();
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
      final commentsRef = FirebaseDatabase.instance
          .ref()
          .child('posts')
          .child(widget.photo.id)
          .child('comments');

      await commentsRef.push().set({
        'userId': currentUser.uid,
        'content': content.trim(),
        'timestamp': ServerValue.timestamp,
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
                  child: StreamBuilder<DatabaseEvent>(
                    stream: FirebaseDatabase.instance
                        .ref()
                        .child('posts')
                        .child(widget.photo.id)
                        .child('comments')
                        .orderByChild('timestamp')
                        .limitToLast(100)
                        .onValue,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                        return const Center(child: Text('No comments yet'));
                      }

                      final commentsData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                      final commentsList = commentsData.entries.map((entry) {
                        final comment = entry.value as Map<dynamic, dynamic>;
                        return {
                          'userId': comment['userId'] as String,
                          'content': comment['content'] as String,
                          'timestamp': comment['timestamp'] as int,
                        };
                      }).toList()
                        ..sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

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