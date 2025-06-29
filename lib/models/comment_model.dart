class CommentModel {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;

  CommentModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
  });
} 