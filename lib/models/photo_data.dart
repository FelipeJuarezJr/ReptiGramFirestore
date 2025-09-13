class PhotoData {
  final String id;
  final dynamic file;
  final String? firebaseUrl;
  final String? thumbnailUrl;  // WebP thumbnail URL
  final String? mediumUrl;     // WebP medium URL  
  final String? fullUrl;       // WebP full URL
  final String? thumbnailUrlJPEG;  // JPEG fallback thumbnail
  final String? mediumUrlJPEG;     // JPEG fallback medium
  final String? fullUrlJPEG;       // JPEG fallback full
  String title;
  bool isLiked;
  String comment;
  final String? userId;
  final int? timestamp;
  int likesCount;
  
  // Cached like data (Phase 2 optimization)
  final List<String>? recentLikers;  // Last 5 user IDs who liked this photo
  final Map<String, bool>? likesMap; // Map of userId -> isLiked for current page

  PhotoData({
    required this.id,
    required this.file,
    this.firebaseUrl,
    this.thumbnailUrl,
    this.mediumUrl,
    this.fullUrl,
    this.thumbnailUrlJPEG,
    this.mediumUrlJPEG,
    this.fullUrlJPEG,
    this.title = 'Photo Details',
    this.isLiked = false,
    this.comment = '',
    this.userId,
    this.timestamp,
    this.likesCount = 0,
    this.recentLikers,
    this.likesMap,
  }) : assert(id.isNotEmpty, 'Photo ID cannot be empty');

  /// Get the best available image URL based on size preference (WebP with JPEG fallback)
  String? getImageUrl({String size = 'thumbnail'}) {
    switch (size) {
      case 'thumbnail':
        return thumbnailUrl ?? thumbnailUrlJPEG ?? mediumUrl ?? mediumUrlJPEG ?? fullUrl ?? fullUrlJPEG ?? firebaseUrl;
      case 'medium':
        return mediumUrl ?? mediumUrlJPEG ?? fullUrl ?? fullUrlJPEG ?? firebaseUrl;
      case 'full':
        return fullUrl ?? fullUrlJPEG ?? firebaseUrl;
      default:
        return firebaseUrl;
    }
  }
} 