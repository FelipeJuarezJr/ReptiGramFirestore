import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/paginated_posts_service.dart';

class InfiniteScrollPosts extends StatefulWidget {
  final List<PostModel> posts;
  final Function(List<PostModel>) onPostsUpdated;
  final Function(PostModel) onPostTap;
  final Function(PostModel) onLikePost;

  const InfiniteScrollPosts({
    Key? key,
    required this.posts,
    required this.onPostsUpdated,
    required this.onPostTap,
    required this.onLikePost,
  }) : super(key: key);

  @override
  State<InfiniteScrollPosts> createState() => _InfiniteScrollPostsState();
}

class _InfiniteScrollPostsState extends State<InfiniteScrollPosts> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !PaginatedPostsService.hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newPosts = await PaginatedPostsService.loadPosts();
      if (newPosts.isNotEmpty) {
        widget.onPostsUpdated([...widget.posts, ...newPosts]);
      }
    } catch (e) {
      print('❌ Error loading more posts: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: widget.posts.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.posts.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final post = widget.posts[index];
        return _buildPostCard(post);
      },
    );
  }

  Widget _buildPostCard(PostModel post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => widget.onPostTap(post),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text(
                      post.authorName.isNotEmpty 
                          ? post.authorName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatTimestamp(post.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Title
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Content
              Text(
                post.content,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Image if available
              if (post.imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    post.imageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 50),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Actions
              Row(
                children: [
                  GestureDetector(
                    onTap: () => widget.onLikePost(post),
                    child: Row(
                      children: [
                        Icon(
                          post.isLiked ? Icons.favorite : Icons.favorite_border,
                          color: post.isLiked ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${post.likesCount}',
                          style: TextStyle(
                            color: post.isLiked ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  const Icon(Icons.comment, color: Colors.grey, size: 20),
                  const SizedBox(width: 4),
                  const Text(
                    'Comment',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
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