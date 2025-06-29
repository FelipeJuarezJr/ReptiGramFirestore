class CommentData {
  final String id;
  final String userId;
  final String content;
  final int timestamp;
  String? username;  // Will be fetched separately

  CommentData({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.username,
  });

  factory CommentData.fromMap(String id, Map<dynamic, dynamic> map) {
    return CommentData(
      id: id,
      userId: map['userId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'content': content,
      'timestamp': timestamp,
    };
  }
} 