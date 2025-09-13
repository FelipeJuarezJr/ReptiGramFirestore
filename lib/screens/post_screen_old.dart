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


  Future<void> _loadPosts() async {
    try {
      if (!mounted) return;
      
      print('DEBUG: Loading posts...');
      setState(() => _isLoading = true);

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('DEBUG: No authenticated user found');
        setState(() => _isLoading = false);
        return;
      }

      // Get all posts ordered by timestamp
      final postsQuery = await FirestoreService.posts
          .orderBy('timestamp', descending: true)
          .get();
      
      print('DEBUG: Fetched ${postsQuery.docs.length} posts from Firestore');

      if (postsQuery.docs.isEmpty) {
        print('DEBUG: No posts found');
        setState(() {
          _posts.clear();
          _isLoading = false;
        });
        return;
      }

      // Get follow status for current user
      List<String> followedUserIds = [];
      try {
        followedUserIds = await FirestoreService.getFollowedUserIds(userId);
        print('DEBUG: User is following ${followedUserIds.length} users');
      } catch (e) {
        print('DEBUG: Could not fetch follow status: $e');
        followedUserIds = [];
      }

      // Process posts
      final List<PostModel> loadedPosts = [];
      
      for (var doc in postsQuery.docs) {
        if (!mounted) return;
        
        try {
          final data = doc.data() as Map<String, dynamic>;
          final postId = doc.id;
          final postUserId = data['userId'] ?? '';
          
          // Check if current user is following the post author
          final isFollowing = followedUserIds.contains(postUserId);

          // Create post model
          final postTimestamp = data['timestamp'] is Timestamp 
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0);
          
          final post = PostModel(
            id: postId,
            userId: postUserId,
            content: data['content'] ?? '[No content]',
            timestamp: postTimestamp,
            isLiked: false, // Will be updated later if needed
            likeCount: 0,   // Will be updated later if needed
            comments: [],    // Will be updated later if needed
            isFollowing: isFollowing,
          );
          loadedPosts.add(post);
        } catch (e) {
          print('DEBUG: Error processing post: $e');
        }
      }

      print('DEBUG: Processed ${loadedPosts.length} posts');

      // Sort posts: followed users first, then by timestamp
      loadedPosts.sort((a, b) {
        if (a.isFollowing && !b.isFollowing) return -1;
        if (!a.isFollowing && b.isFollowing) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(loadedPosts);
        });
        print('DEBUG: Posts loaded: ${_posts.length}');
      }
    } catch (e) {
      print('DEBUG: Error loading posts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (!mounted) return;
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
      await _loadPosts(); // Reload posts
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
    // Store the original state for potential rollback
    final originalFollowingState = post.isFollowing;
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Don't allow following yourself
      if (userId == post.userId) return;
      
      // Optimistic update - immediately change the UI for ALL posts from this user
      if (mounted) {
        setState(() {
          // Update the clicked post
          post.isFollowing = !post.isFollowing;
          
          // Update ALL posts from the same user
          for (int i = 0; i < _posts.length; i++) {
            if (_posts[i].userId == post.userId) {
              _posts[i].isFollowing = post.isFollowing;
            }
          }
        });

      }

      // Firestore: Toggle follow
      try {
        if (post.isFollowing) {
          await FirestoreService.followUser(userId, post.userId);
  
        } else {
          await FirestoreService.unfollowUser(userId, post.userId);
  
        }
        
        // Update the following users count in the UI
        setState(() {});
        
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

        // If follow operation fails, revert the UI state for ALL posts from this user
        if (mounted) {
          setState(() {
            // Revert the clicked post
            post.isFollowing = originalFollowingState;
            
            // Revert ALL posts from the same user
            for (int i = 0; i < _posts.length; i++) {
              if (_posts[i].userId == post.userId) {
                _posts[i].isFollowing = originalFollowingState;
              }
            }
          });
        }
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update follow status. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

    } catch (e) {
      // Revert on error for ALL posts from this user
      if (mounted) {
        setState(() {
          // Revert the clicked post
          post.isFollowing = originalFollowingState;
          
          // Revert ALL posts from the same user
          for (int i = 0; i < _posts.length; i++) {
            if (_posts[i].userId == post.userId) {
              _posts[i].isFollowing = originalFollowingState;
            }
          }
        });
      }

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
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: const Text(
            'Delete Post',
            style: TextStyle(color: AppColors.titleText),
          ),
          content: Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: const TextStyle(color: AppColors.titleText),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown,
              ),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
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

        Navigator.pop(context); // Hide loading indicator
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
          await _loadPosts(); // Reload posts to update the UI
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
    final commentController = TextEditingController();
    final appState = Provider.of<AppState>(context, listen: false);
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppColors.pillShape,
          ),
          title: const Text(
            'Add Comment',
            style: TextStyle(color: Colors.brown),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: commentController,
                    style: TextStyle(color: Colors.brown),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                        borderSide: BorderSide(color: Colors.brown),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Image upload section
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
                            setDialogState(() {
                              selectedImage = image;
                            });
                          }
                        },
                      ),
                      const Text(
                        'Add Image',
                        style: TextStyle(color: Colors.brown),
                      ),
                      const Spacer(),
                      if (selectedImage != null)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setDialogState(() {
                              selectedImage = null;
                            });
                          },
                        ),
                    ],
                  ),
                  // Show selected image preview
                  if (selectedImage != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? FutureBuilder<Uint8List>(
                                future: selectedImage!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                    );
                                  } else {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                },
                              )
                            : Image.file(
                                File(selectedImage!.path),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (post.comments.isNotEmpty) ...[
                    const Text(
                      'Comments:',
                      style: TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: post.comments.length,
                        itemBuilder: (context, index) {
                          final comment = post.comments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildUserAvatar(comment.userId),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FutureBuilder<String?>(
                                        future: appState.fetchUsername(comment.userId),
                                        builder: (context, snapshot) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: '${snapshot.data ?? 'Loading...'}: ',
                                                      style: const TextStyle(
                                                        color: Colors.brown,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: comment.content,
                                                      style: const TextStyle(color: Colors.brown),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Show image if comment has one
                                              if (comment.imageUrl != null) ...[
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
                                                      comment.imageUrl!,
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
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatTimestamp(comment.timestamp),
                                        style: TextStyle(
                                          color: Colors.brown[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (commentController.text.trim().isNotEmpty || selectedImage != null) {
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
                  
                  await _addComment(post, commentController.text.trim(), imageFile: selectedImage);
                  
                  // Hide loading indicator and close dialog
                  Navigator.pop(context); // Close loading indicator
                  Navigator.pop(context); // Close comment dialog
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.brown,
              ),
              child: const Text('Comment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addComment(PostModel post, String content, {XFile? imageFile}) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Ensure we have the username for the commenter
      await _fetchUsername(userId);

      String? imageUrl;
      
      // Upload image if provided
      if (imageFile != null) {
        try {
          final String commentImageId = DateTime.now().millisecondsSinceEpoch.toString();
          final Reference ref = FirebaseStorage.instance
              .ref()
              .child('comment_images')
              .child(userId)
              .child(commentImageId);
          
          if (kIsWeb) {
            final bytes = await imageFile.readAsBytes();
            await ref.putData(
              bytes,
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'userId': userId,
                  'uploadedAt': DateTime.now().toString(),
                },
              ),
            );
          } else {
            await ref.putFile(
              File(imageFile.path),
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'userId': userId,
                  'uploadedAt': DateTime.now().toString(),
                },
              ),
            );
          }
          
          imageUrl = await ref.getDownloadURL();
        } catch (e) {
          print('Error uploading comment image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload image: ${e.toString()}')),
            );
          }
          return;
        }
      }

      // Firestore: Add comment
      final commentDoc = await FirestoreService.comments.add({
        'postId': post.id,
        'userId': userId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      });

      // Optimistic update
      final newComment = CommentModel(
        id: commentDoc.id,
        userId: userId,
        content: content,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
      );

      if (mounted) {
        setState(() {
          post.comments.add(newComment);
        });
      }

    } catch (e) {
      print('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
        );
      }
    }
  }



  Future<void> _fetchUsername(String userId) async {
    if (_usernames.containsKey(userId)) return;

    try {
      // Firestore: Get username
      final userDoc = await FirestoreService.users.doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          final username = data['username'] ?? 'Unknown User';
          if (mounted) {
          setState(() {
            _usernames[userId] = username;
          });
          }
        }
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  Future<void> _loadUsernames() async {
    try {
      // Firestore: Get all users
      try {
      final usersQuery = await FirestoreService.users.get();

      for (var doc in usersQuery.docs) {
          try {
        final data = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        
        // First try to get username from the root level
        String? username = data['username'];
        
        // If not found, try to get it from the profile
        if (username == null && data['profile'] is Map) {
          final profile = data['profile'];
          username = profile['username'] ?? 
                     profile['displayName'] ?? 
                     'Unknown User';
            }
            
            // If still not found, try displayName directly
            if (username == null) {
              username = data['displayName'] ?? 'Unknown User';
            }
            
            // If still not found, use Unknown User
            _usernames[userId] = username ?? 'Unknown User';
          } catch (e) {
            // Continue processing other users if one fails
          }
        }
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        // Handle error silently
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _fetchUsernamesBatch(Set<String> userIds) async {
    try {
      // Get all users in one query
      final usersQuery = await FirestoreService.users.get();
      
      for (var doc in usersQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        
        if (userIds.contains(userId)) {
          // First try to get username from the root level
          String? username = data['username'];
          
          // If not found, try to get it from the profile
          if (username == null && data['profile'] is Map) {
            final profile = data['profile'];
            username = profile['username'] ?? 
                       profile['displayName'] ?? 
                       'Unknown User';
          }
          
          // If still not found, try displayName directly
          if (username == null) {
            username = data['displayName'] ?? 'Unknown User';
          }
        
          // If still not found, use Unknown User
          _usernames[userId] = username ?? 'Unknown User';
        }
      }
    } catch (e) {
      // Handle error silently
    }
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
            radius: 12,
            backgroundImage: const AssetImage('assets/img/reptiGramLogo.png'),
          );
        }

        // Show network image with proper error handling
        return CircleAvatar(
          radius: 12,
          backgroundImage: NetworkImage(avatarUrl),
          onBackgroundImageError: (exception, stackTrace) {
            // Handle image loading errors by showing app logo
            print('Post avatar image failed to load: $avatarUrl, error: $exception');
            if (mounted) {
              // Use post-frame callback to avoid calling setState during paint
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _avatarUrls[userId] = null;
                  });
                }
              });
            }
          },
        );
      },
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
                                'Create Post',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.titleText,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildPostCreationForm(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Right side - Posts feed
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0),
                    child: _buildPostsFeed(context, appState, null),
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
                          style: AppColors.pillButtonStyle,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppColors.loginGradient,
                              borderRadius: AppColors.pillShape,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              alignment: Alignment.center,
                              child: const Text(
                                'Create Post',
                                style: TextStyle(
                                  color: AppColors.buttonText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),

        // Scrollable Posts List
        Expanded(
          child: _buildPostsFeed(context, appState, postWidth),
        ),
      ],
    );
  }

  Widget _buildPostCreationForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.inputGradient,
              borderRadius: AppColors.pillShape,
            ),
            child: TextFormField(
              controller: _descriptionController,
              maxLines: 4,
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
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createPost,
                    style: AppColors.pillButtonStyle,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.loginGradient,
                        borderRadius: AppColors.pillShape,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: const Text(
                          'Create Post',
                          style: TextStyle(
                            color: AppColors.buttonText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPostsFeed(BuildContext context, AppState appState, double? postWidth) {
    return Column(
      children: [
        // Follow summary section
        FutureBuilder<List<String>>(
          key: const ValueKey('following_section'),
          future: FirebaseAuth.instance.currentUser != null 
              ? FirestoreService.getFollowedUserIds(FirebaseAuth.instance.currentUser!.uid)
                  .catchError((e) {
                    print('DEBUG: Could not fetch follow count: $e');
                    return <String>[];
                  })
              : Future.value([]),
          builder: (context, snapshot) {
            final followedUserIds = snapshot.data ?? [];
            final followingCount = followedUserIds.length;
            
            return StatefulBuilder(
              builder: (context, setLocalState) {
                return GestureDetector(
                  onTap: () {
                    setLocalState(() {
                      _isFollowedUsersExpanded = !_isFollowedUsersExpanded;
                    });
                    // Also update the main state to ensure consistency
                    setState(() {});
                  },
                  child: Container(
                    width: postWidth,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.brown[50]!, Colors.brown[100]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppColors.pillShape,
                      border: Border.all(color: Colors.brown[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              color: Colors.brown[600],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Following $followingCount users',
                              style: TextStyle(
                                color: Colors.brown[700],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (_isFollowedUsersExpanded)
                              Icon(
                                Icons.keyboard_arrow_up,
                                color: Colors.brown[600],
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.brown[600],
                                size: 20,
                              ),
                          ],
                        ),
                        // Show followed usernames only when expanded
                        if (_isFollowedUsersExpanded) ...[
                          const SizedBox(height: 16),
                          if (followedUserIds.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'You are not following any users yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Following:',
                                      style: TextStyle(
                                        color: Colors.brown,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${followedUserIds.length} total)',
                                      style: TextStyle(
                                        color: Colors.brown[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Usernames list
                                ...followedUserIds.map((userId) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Row(
                                    children: [
                                      _buildUserAvatar(userId),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _usernames[userId] ?? 'Loading...',
                                          style: const TextStyle(
                                            color: Colors.brown,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
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
