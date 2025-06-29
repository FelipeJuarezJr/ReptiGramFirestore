import 'package:flutter/material.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import 'package:intl/intl.dart';

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
    // Always load posts when screen is mounted
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      setState(() => _isLoading = true);

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final postsRef = FirebaseDatabase.instance
          .ref()
          .child('posts')
          .orderByChild('timestamp');

      final snapshot = await postsRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        setState(() {
          _posts.clear();
          _isLoading = false;
        });
        return;
      }

      try {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<PostModel> loadedPosts = [];

        data.forEach((key, value) {
          try {
            Map<dynamic, dynamic> likesMap = {};
            if (value['likes'] != null) {
              likesMap = value['likes'] as Map<dynamic, dynamic>;
            }
            final isLiked = likesMap.containsKey(userId);
            final likeCount = likesMap.length;

            // Parse comments
            final List<CommentModel> comments = [];
            if (value['comments'] != null) {
              (value['comments'] as Map<dynamic, dynamic>).forEach((commentKey, commentValue) {
                comments.add(CommentModel(
                  id: commentKey,
                  userId: commentValue['userId'] ?? '',
                  content: commentValue['content'] ?? '',
                  timestamp: DateTime.fromMillisecondsSinceEpoch(commentValue['timestamp'] ?? 0),
                ));
              });
            }

            // Create post model with actual timestamp
            final post = PostModel(
              id: key,
              userId: value['userId'] ?? '',
              content: value['content'] ?? '',
              timestamp: DateTime.fromMillisecondsSinceEpoch(value['timestamp'] ?? 0),
              isLiked: isLiked,
              likeCount: likeCount,
              comments: comments,
            );
            loadedPosts.add(post);

            if (post.userId.isNotEmpty) {
              _fetchUsername(post.userId);
            }
          } catch (e) {
            print('Error processing individual post: $e');
          }
        });

        // Sort by timestamp (newest first)
        loadedPosts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _posts.clear();
          _posts.addAll(loadedPosts);
        });
      } catch (e) {
        print('Error processing posts data: $e');
      }
    } catch (e) {
      print('Error loading posts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final content = _descriptionController.text.trim();
      final postId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create post data
      final postData = {
        'userId': userId,
        'content': content,
        'timestamp': ServerValue.timestamp,
        'likes': {},
        'comments': {},
      };

      // Save to Firebase
      await FirebaseDatabase.instance
          .ref()
          .child('posts')
          .child(postId)
          .set(postData);

      _descriptionController.clear();
      await _loadPosts(); // Reload posts

    } catch (e) {
      print('Error creating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create post: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(PostModel post) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final postRef = FirebaseDatabase.instance
          .ref()
          .child('posts')
          .child(post.id)
          .child('likes')
          .child(userId);

      // Optimistic update
      setState(() {
        post.isLiked = !post.isLiked;
        post.likeCount += post.isLiked ? 1 : -1;
      });

      if (post.isLiked) {
        await postRef.set(true);
      } else {
        await postRef.remove();
      }

    } catch (e) {
      // Revert on error
      setState(() {
        post.isLiked = !post.isLiked;
        post.likeCount += post.isLiked ? 1 : -1;
      });
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: ${e.toString()}')),
      );
    }
  }

  void _showCommentDialog(PostModel post) {
    final commentController = TextEditingController();

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
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${_usernames[comment.userId] ?? 'Loading...'}: ',
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

      final commentId = DateTime.now().millisecondsSinceEpoch.toString();
      final commentData = {
        'userId': userId,
        'content': content,
        'timestamp': ServerValue.timestamp,
      };

      // Add comment to Firebase
      await FirebaseDatabase.instance
          .ref()
          .child('posts')
          .child(post.id)
          .child('comments')
          .child(commentId)
          .set(commentData);

      // Optimistic update
      final newComment = CommentModel(
        id: commentId,
        userId: userId,
        content: content,
        timestamp: DateTime.now(),
      );

      setState(() {
        post.comments.add(newComment);
      });

    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
      );
    }
  }

  Future<void> _fetchUsername(String userId) async {
    if (_usernames.containsKey(userId)) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userId)
          .child('username')
          .get();

      if (snapshot.value != null) {
        setState(() {
          _usernames[userId] = snapshot.value.toString();
        });
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  Future<void> _loadUsernames() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((userId, userData) {
          if (userData is Map) {
            // First try to get username from the root level
            String? username = userData['username'];
            
            // If not found, try to get it from the profile
            if (username == null && userData['profile'] is Map) {
              final profile = userData['profile'];
              username = profile['username'] ?? 
                         profile['displayName'] ?? 
                         'Unknown User';
            }
            
            // If still not found, use Unknown User
            _usernames[userId] = username ?? 'Unknown User';
            print('Loaded username for $userId: ${_usernames[userId]}'); // Debug print
          }
        });
        setState(() {});
      }
    } catch (e) {
      print('Error loading usernames: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                                Text(
                                  _usernames[post.userId] ?? 'Loading...',
                                  style: const TextStyle(
                                    color: Colors.brown,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
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
                                    Text(
                                      'Latest: ${_usernames[post.comments.last.userId] ?? 'Loading...'}: ${post.comments.last.content}',
                                      style: const TextStyle(
                                        color: Colors.brown,
                                        fontSize: 14,
                                      ),
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