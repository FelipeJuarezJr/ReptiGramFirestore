import 'comment_model.dart';

class PostModel {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String? imageUrl; // Optional image URL for image posts
  bool isLiked;
  int likeCount;
  List<CommentModel> comments;
  bool isFollowing; // Track if current user is following the post author

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.imageUrl,
    this.isLiked = false,
    this.likeCount = 0,
    List<CommentModel>? comments,
    this.isFollowing = false,
  }) : comments = comments ?? [];
} 