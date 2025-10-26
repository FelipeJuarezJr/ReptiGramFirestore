import 'comment_model.dart';

class PostModel {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String? imageUrl; // Optional image URL for image posts
  final String? videoUrl; // Optional video URL for video posts
  final String? thumbnailUrl; // Optional thumbnail for video posts
  final String? mediaType; // 'image', 'video', or null for text-only
  bool isLiked;
  int likeCount;
  List<CommentModel> comments;
  bool isFollowing; // Track if current user is following the post author
  final String title; // Post title
  final String authorName; // Author display name
  final int likesCount; // Number of likes

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.imageUrl,
    this.videoUrl,
    this.thumbnailUrl,
    this.mediaType,
    this.isLiked = false,
    this.likeCount = 0,
    List<CommentModel>? comments,
    this.isFollowing = false,
    this.title = 'Untitled Post',
    this.authorName = 'Unknown User',
    this.likesCount = 0,
  }) : comments = comments ?? [];
} 