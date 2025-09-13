import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../state/app_state.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../widgets/infinite_scroll_posts.dart';
import 'dart:io';
import 'dart:typed_data';
import '../utils/responsive_utils.dart';

class PostScreen extends StatefulWidget {
  final bool shouldLoadPosts;
  
  const PostScreen({
    super.key,
    this.shouldLoadPosts = false,
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  final Map<String, String> _usernames = {};
  final Map<String, String?> _avatarUrls = {}; // Cache for avatar URLs
  bool _isFollowedUsersExpanded = false; // Track if followed users list is expanded

  @override
  void initState() {
    super.initState();
    _loadUsernames();
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final content = _descriptionController.text.trim();

      // Firestore: Create post
      await FirestoreService.posts.add({
        'userId': userId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _descriptionController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
      }

    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLike(PostModel post) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Optimistic update
      if (mounted) {
        setState(() {
          post.isLiked = !post.isLiked;
          post.likeCount += post.isLiked ? 1 : -1;
        });
      }

      // Firestore: Toggle like
      if (post.isLiked) {
        await FirestoreService.likes.add({
          'postId': post.id,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Find and delete the like document
        final likeQuery = await FirestoreService.likes
            .where('postId', isEqualTo: post.id)
            .where('userId', isEqualTo: userId)
            .get();
        
        for (var doc in likeQuery.docs) {
          await doc.reference.delete();
        }
      }

    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          post.isLiked = !post.isLiked;
          post.likeCount += post.isLiked ? 1 : -1;
        });
      }
      print('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _toggleFollow(PostModel post) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Toggle follow state
      post.isFollowing = !post.isFollowing;

      if (mounted) {
        setState(() {});
      }

      // Firestore: Toggle follow
      if (post.isFollowing) {
        await FirestoreService.followUser(userId, post.userId);
      } else {
        await FirestoreService.unfollowUser(userId, post.userId);
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(post.isFollowing ? 'Now following this user!' : 'Unfollowed this user'),
            backgroundColor: post.isFollowing ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      post.isFollowing = !post.isFollowing;
      if (mounted) {
        setState(() {});
      }
      print('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deletePost(PostModel post) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId != post.userId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        // Delete likes for this post
        final likesQuery = await FirestoreService.likes
            .where('postId', isEqualTo: post.id)
            .get();

        // Delete comments for this post
        final commentsQuery = await FirestoreService.comments
            .where('postId', isEqualTo: post.id)
            .get();

        // Delete post document and related data
        final batch = FirebaseFirestore.instance.batch();
        
        for (var likeDoc in likesQuery.docs) {
          batch.delete(likeDoc.reference);
        }
        
        for (var commentDoc in commentsQuery.docs) {
          batch.delete(commentDoc.reference);
        }
        
        batch.delete(FirestoreService.posts.doc(post.id));
        
        await batch.commit();

        // Hide loading indicator
        Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
        }
      } catch (e) {
        Navigator.pop(context); // Hide loading indicator
        print('Error deleting post: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete post: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _showCommentDialog(PostModel post) {
    // Simple comment dialog - you can implement this later
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comment functionality coming soon!')),
    );
  }

  Future<void> _loadUsernames() async {
    // Load usernames for display
    // This is a simplified version - you can implement the full logic later
  }

  Widget _buildUserAvatar(String userId) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.brown[100],
      child: Text(
        userId.isNotEmpty ? userId[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.brown,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final postWidth = screenWidth - 32;

    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: SafeArea(
          child: ResponsiveUtils.isWideScreen(context) 
              ? _buildDesktopLayout(context, appState)
              : _buildMobileLayout(context, appState, postWidth),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppState appState) {
    return Column(
      children: [
        const TitleHeader(),
        const Header(initialIndex: 0),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Post creation form
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0, right: 16.0),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF8E1), // Light cream
                              Color(0xFFFFE0B2), // Light orange
                              Color(0xFFFFCC80), // Medium orange
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Create New Post',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.brown,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _descriptionController,
                                      maxLines: 5,
                                      decoration: InputDecoration(
                                        hintText: 'What\'s happening in the ReptiWorld?',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a Post';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _isLoading
                                        ? const CircularProgressIndicator()
                                        : SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: _createPost,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.brown,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text(
                                                'Post',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Right side - Posts list
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0),
                    child: InfiniteScrollPosts(
                      itemWidth: postWidth,
                      itemBuilder: (post) => _buildPostItem(post, postWidth, appState),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppState appState, double postWidth) {
    return Column(
      children: [
        const TitleHeader(),
        const Header(initialIndex: 0),
        
        // Fixed Post Creation Form
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: postWidth,
                  decoration: BoxDecoration(
                    gradient: AppColors.inputGradient,
                    borderRadius: AppColors.pillShape,
                  ),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'What\'s happening in the ReptiWorld?',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a Post';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: ElevatedButton(
                          onPressed: _createPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text(
                            'Post',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
        // Posts list with infinite scroll
        Expanded(
          child: InfiniteScrollPosts(
            itemWidth: postWidth,
            itemBuilder: (post) => _buildPostItem(post, postWidth, appState),
          ),
        ),
      ],
    );
  }

  Widget _buildPostItem(PostModel post, double postWidth, AppState appState) {
    return Container(
      width: postWidth,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: AppColors.inputGradient,
        borderRadius: AppColors.pillShape,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info and actions
            Row(
              children: [
                _buildUserAvatar(post.userId),
                const SizedBox(width: 8),
                Expanded(
                  child: FutureBuilder<String?>(
                    future: appState.fetchUsername(post.userId),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Loading...',
                        style: const TextStyle(
                          color: Colors.brown,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ),
                // Follow button - only show if not the current user's post
                if (FirebaseAuth.instance.currentUser?.uid != post.userId)
                  TextButton(
                    onPressed: () => _toggleFollow(post),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      backgroundColor: post.isFollowing 
                          ? Colors.grey[300] 
                          : Colors.brown[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      post.isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: post.isFollowing 
                            ? Colors.grey[700] 
                            : Colors.brown[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                // Delete button - only show for current user's posts
                if (FirebaseAuth.instance.currentUser?.uid == post.userId)
                  TextButton(
                    onPressed: () => _deletePost(post),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      backgroundColor: Colors.red[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Post content
            Text(
              post.content,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            // Post image if available
            if (post.imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Post actions (like, comment, timestamp)
            Row(
              children: [
                IconButton(
                  onPressed: () => _toggleLike(post),
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : Colors.grey,
                  ),
                ),
                Text(
                  '${post.likeCount}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => _showCommentDialog(post),
                  icon: const Icon(
                    Icons.comment_outlined,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '${post.comments.length}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(post.timestamp),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
