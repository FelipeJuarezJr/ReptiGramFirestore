import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../state/app_state.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

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
  final List<PostModel> _posts = [];
  bool _isLoading = false;
  final Map<String, String> _usernames = {};

  @override
  void initState() {
    super.initState();
    // Test Firestore access first
    _testFirestoreAccess();
    // Always load posts when screen is mounted
    _loadPosts();
    _loadUsernames();
  }

  Future<void> _testFirestoreAccess() async {
    try {
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      
      // Test posts collection
      final postsTest = await FirestoreService.posts.limit(1).get();
      
      // Test users collection
      final usersTest = await FirestoreService.users.limit(1).get();
      
      // Test comments collection
      final commentsTest = await FirestoreService.comments.limit(1).get();
      
      // Test likes collection
      final likesTest = await FirestoreService.likes.limit(1).get();
      
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadPosts() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return;
      }

      // Firestore: Get all posts ordered by timestamp
      try {
        // First try to get posts ordered by timestamp
        QuerySnapshot postsQuery;
        try {
          postsQuery = await FirestoreService.posts
          .orderBy('timestamp', descending: true)
          .get();
        } catch (e) {
          // If timestamp ordering fails, get posts without ordering
          postsQuery = await FirestoreService.posts.get();
        }

        if (!mounted) return;

      if (postsQuery.docs.isEmpty) {
        setState(() {
          _posts.clear();
          _isLoading = false;
        });
        return;
      }

      try {
          // Get all likes and comments in batch queries
          
          // Get all likes
          final likesQuery = await FirestoreService.likes.get();
          final likesMap = <String, Map<String, bool>>{};
            for (var likeDoc in likesQuery.docs) {
              final likeData = likeDoc.data() as Map<String, dynamic>;
            final postId = likeData['postId'] as String?;
              final likeUserId = likeData['userId'] as String?;
            if (postId != null && likeUserId != null) {
              likesMap.putIfAbsent(postId, () => {});
              likesMap[postId]![likeUserId] = true;
            }
          }

          // Get all comments
          final commentsQuery = await FirestoreService.comments.get();
          final commentsMap = <String, List<CommentModel>>{};
            for (var commentDoc in commentsQuery.docs) {
              final commentData = commentDoc.data() as Map<String, dynamic>;
            final postId = commentData['postId'] as String?;
            if (postId != null) {
              final timestamp = commentData['timestamp'] is Timestamp 
                  ? (commentData['timestamp'] as Timestamp).toDate()
                  : DateTime.fromMillisecondsSinceEpoch(commentData['timestamp'] ?? 0);
              
              final comment = CommentModel(
                id: commentDoc.id,
                userId: commentData['userId'] ?? '',
                content: commentData['content'] ?? '',
                timestamp: timestamp,
              );
              
              commentsMap.putIfAbsent(postId, () => []);
              commentsMap[postId]!.add(comment);
            }
          }

          // Process posts using the batch data
          final List<PostModel> loadedPosts = [];
          final Set<String> userIdsToFetch = <String>{};

          for (var doc in postsQuery.docs) {
            if (!mounted) return;
            
            try {
              final data = doc.data() as Map<String, dynamic>;
              final postId = doc.id;
              
              // Get likes for this post from batch data
              final postLikes = likesMap[postId] ?? {};
              final isLiked = postLikes.containsKey(userId);
              final likeCount = postLikes.length;

              // Get comments for this post from batch data
              final postComments = commentsMap[postId] ?? [];

            // Create post model with actual timestamp
            final postTimestamp = data['timestamp'] is Timestamp 
                ? (data['timestamp'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0);
            
            final post = PostModel(
              id: postId,
              userId: data['userId'] ?? '',
                content: data['content'] ?? '[No content]',
              timestamp: postTimestamp,
              isLiked: isLiked,
              likeCount: likeCount,
                comments: postComments,
            );
            loadedPosts.add(post);

              // Collect user IDs to fetch usernames in batch
            if (post.userId.isNotEmpty) {
                userIdsToFetch.add(post.userId);
              }
              for (var comment in postComments) {
                if (comment.userId.isNotEmpty) {
                  userIdsToFetch.add(comment.userId);
                }
            }
          } catch (e) {
              // Continue processing other posts if one fails
          }
        }

          // Fetch all usernames in batch
          await _fetchUsernamesBatch(userIdsToFetch);

          if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(loadedPosts);
        });
          }
        } catch (e) {
          // Handle error silently
        }
      } catch (e) {
        // Handle error silently
      }
    } catch (e) {
      // Handle error silently
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

  void _showCommentDialog(PostModel post) {
    final commentController = TextEditingController();
    final appState = Provider.of<AppState>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<String?>(
                                future: appState.fetchUsername(comment.userId),
                                builder: (context, snapshot) {
                                  return RichText(
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
            onPressed: () {
              if (commentController.text.trim().isNotEmpty) {
                _addComment(post, commentController.text.trim());
                Navigator.pop(context);
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
    );
  }

  Future<void> _addComment(PostModel post, String content) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Ensure we have the username for the commenter
      await _fetchUsername(userId);

      // Firestore: Add comment
      final commentDoc = await FirestoreService.comments.add({
        'postId': post.id,
        'userId': userId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Optimistic update
      final newComment = CommentModel(
        id: commentDoc.id,
        userId: userId,
        content: content,
        timestamp: DateTime.now(),
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
          child: Column(
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    final post = _posts[index];
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_circle,
                                  color: Colors.brown,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                FutureBuilder<String?>(
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
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              post.content,
                              style: const TextStyle(
                                color: Colors.brown,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: post.isLiked ? Colors.red : Colors.brown[400],
                                  ),
                                  onPressed: () => _toggleLike(post),
                                ),
                                Text(
                                  '${post.likeCount} likes',
                                  style: TextStyle(
                                    color: Colors.brown[400],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: Icon(
                                    Icons.comment_outlined,
                                    color: Colors.brown[400],
                                  ),
                                  onPressed: () => _showCommentDialog(post),
                                ),
                                Text(
                                  '${post.comments.length} comments',
                                  style: TextStyle(
                                    color: Colors.brown[400],
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatTimestamp(post.timestamp),
                                  style: TextStyle(
                                    color: Colors.brown[400],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            // Show latest comment if exists
                            if (post.comments.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.brown.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<String?>(
                                      future: appState.fetchUsername(post.comments.last.userId),
                                      builder: (context, snapshot) {
                                        return Text(
                                          'Latest: ${snapshot.data ?? 'Loading...'}: ${post.comments.last.content}',
                                          style: const TextStyle(
                                            color: Colors.brown,
                                            fontSize: 14,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(post.comments.last.timestamp),
                                      style: TextStyle(
                                        color: Colors.brown[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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