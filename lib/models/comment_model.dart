class CommentModel {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String? imageUrl; // Optional image URL for image comments

  CommentModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.imageUrl,
  });
} 