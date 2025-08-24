import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import '../models/post_model.dart';
import '../state/app_state.dart';
import '../services/firestore_service.dart';
import '../widgets/user_profile_card.dart';
import '../utils/responsive_utils.dart';

class TimelineFeedScreen extends StatefulWidget {
  const TimelineFeedScreen({super.key});

  @override
  State<TimelineFeedScreen> createState() => _TimelineFeedScreenState();
}

class _TimelineFeedScreenState extends State<TimelineFeedScreen> {
  bool _isLoading = false;
  List<PostModel> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get timeline posts
      final timelineSnapshot = await FirestoreService.getUserTimelineStream().first;
      final posts = timelineSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return PostModel.fromDoc(data, doc.id);
      }).toList();

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading timeline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const TitleHeader(title: 'Timeline'),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _posts.isEmpty
                    ? _buildEmptyState()
                    : _buildTimelineList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Follow some users to see their posts here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // TODO: Navigate to user discovery/suggestions
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Discover Users'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList() {
    return StreamBuilder<QuerySnapshot?>(
      stream: FirestoreService.getUserTimelineStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == null) {
          return _buildEmptyState();
        }

        final posts = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return PostModel.fromDoc(data, doc.id);
        }).toList();

        if (posts.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _loadTimeline,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _buildPostCard(post);
            },
          ),
        );
      },
    );
  }

  Widget _buildPostCard(PostModel post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post header with author info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post.authorPhotoUrl != null
                      ? NetworkImage(post.authorPhotoUrl!)
                      : null,
                  child: post.authorPhotoUrl == null
                      ? Text(
                          post.authorUsername?.isNotEmpty == true
                              ? post.authorUsername![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorUsername ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTimestamp(post.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Post content
            if (post.content.isNotEmpty) ...[
              Text(
                post.content,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
            ],
            
            // Post image
            if (post.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.error,
                        size: 48,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Post actions
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    // TODO: Implement like functionality
                  },
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : Colors.grey,
                  ),
                ),
                Text(
                  '${post.likeCount}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {
                    // TODO: Navigate to comments
                  },
                  icon: const Icon(Icons.comment_outlined),
                ),
                Text(
                  '${post.comments.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    // TODO: Show more options
                  },
                  icon: const Icon(Icons.more_vert),
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
