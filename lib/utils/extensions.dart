import '../models/photo_data.dart';

extension PhotoDataExtensions on PhotoData {
  // Check if photo belongs to current user
  bool isOwnedBy(String? userId) => this.userId == userId;

  // Create copy with updates
  PhotoData copyWith({
    String? title,
    bool? isLiked,
    String? comment,
  }) {
    return PhotoData(
      id: id,
      file: file,
      firebaseUrl: firebaseUrl,
      title: title ?? this.title,
      isLiked: isLiked ?? this.isLiked,
      comment: comment ?? this.comment,
      userId: userId,
    );
  }

  // Convert to map for database
  Map<String, dynamic> toMap() {
    return {
      'firebaseUrl': firebaseUrl,
      'title': title,
      'isLiked': isLiked,
      'comment': comment,
      'userId': userId,
      'lastModified': DateTime.now().millisecondsSinceEpoch,
    };
  }
} 