import 'comment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  final String? imageUrl; // Optional image URL for image posts
  bool isLiked;
  int likeCount;
  List<CommentModel> comments;
  final String? authorUsername; // Author's username for display
  final String? authorPhotoUrl; // Author's profile photo

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.imageUrl,
    this.isLiked = false,
    this.likeCount = 0,
    List<CommentModel>? comments,
    this.authorUsername,
    this.authorPhotoUrl,
  }) : comments = comments ?? [];

  // Create from Firestore document
  factory PostModel.fromDoc(Map<String, dynamic> data, String docId) {
    return PostModel(
      id: docId,
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] is DateTime 
          ? data['timestamp'] 
          : (data['timestamp'] as Timestamp).toDate(),
      imageUrl: data['imageUrl'],
      isLiked: data['isLiked'] ?? false,
      likeCount: data['likeCount'] ?? 0,
      comments: [], // Comments will be loaded separately
      authorUsername: data['authorUsername'],
      authorPhotoUrl: data['authorPhotoUrl'],
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'content': content,
      'timestamp': timestamp,
      'imageUrl': imageUrl,
      'likeCount': likeCount,
      'authorUsername': authorUsername,
      'authorPhotoUrl': authorPhotoUrl,
    };
  }

  // Create copy with updates
  PostModel copyWith({
    String? content,
    String? imageUrl,
    bool? isLiked,
    int? likeCount,
    List<CommentModel>? comments,
    String? authorUsername,
    String? authorPhotoUrl,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      content: content ?? this.content,
      timestamp: timestamp,
      imageUrl: imageUrl ?? this.imageUrl,
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      comments: comments ?? this.comments,
      authorUsername: authorUsername ?? this.authorUsername,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
    );
  }
} 