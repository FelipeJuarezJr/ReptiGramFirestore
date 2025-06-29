import 'comment_model.dart';

class PostModel {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  bool isLiked;
  int likeCount;
  List<CommentModel> comments;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.isLiked = false,
    this.likeCount = 0,
    List<CommentModel>? comments,
  }) : comments = comments ?? [];
} 