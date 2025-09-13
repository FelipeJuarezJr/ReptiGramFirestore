import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import '../models/photo_data.dart';
import '../state/app_state.dart';
import '../services/firestore_service.dart';
import '../widgets/infinite_scroll_grid.dart';
import 'dart:typed_data';
import '../utils/responsive_utils.dart';

class FeedScreen extends StatefulWidget {
  final bool showLikedOnly;
  
  const FeedScreen({
    super.key,
    this.showLikedOnly = false,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedCommentImage; // For comment image upload

  @override
  void initState() {
    super.initState();
    print('FeedScreen initialized with showLikedOnly: ${widget.showLikedOnly}');
  }

  Future<void> _toggleLike(PhotoData photo) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Optimistic update
      if (mounted) {
        setState(() {
          photo.isLiked = !photo.isLiked;
          photo.likesCount += photo.isLiked ? 1 : -1;
        });
      }

      // Firestore: Toggle like
      if (photo.isLiked) {
        await FirestoreService.likes.add({
          'photoId': photo.id,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Find and delete the like document
        final likeQuery = await FirestoreService.likes
            .where('photoId', isEqualTo: photo.id)
            .where('userId', isEqualTo: userId)
            .get();
        
        for (var doc in likeQuery.docs) {
          await doc.reference.delete();
        }
      }

    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          photo.isLiked = !photo.isLiked;
          photo.likesCount += photo.isLiked ? 1 : -1;
        });
      }
      print('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildPhotoCard(PhotoData photo) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.inputGradient,
        borderRadius: AppColors.pillShape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
              child: Image.network(
                photo.getImageUrl(size: 'thumbnail') ?? photo.firebaseUrl ?? '',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.error,
                        color: Colors.grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Photo info
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  photo.comment,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _toggleLike(photo),
                      icon: Icon(
                        photo.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: photo.isLiked ? Colors.red : Colors.grey,
                        size: 20,
                      ),
                    ),
                    Text(
                      '${photo.likesCount}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimestamp(photo.timestamp),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(date);

    if (difference.inSeconds < 30) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: SafeArea(
          child: ResponsiveUtils.isWideScreen(context) 
              ? _buildDesktopLayout(context, appState)
              : _buildMobileLayout(context, appState),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppState appState) {
    return Column(
      children: [
        const TitleHeader(),
        const Header(initialIndex: 1),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: InfiniteScrollGrid(
              showLikedOnly: widget.showLikedOnly,
              crossAxisCount: 4,
              childAspectRatio: 1.0,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              itemBuilder: (photo) => _buildPhotoCard(photo),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppState appState) {
    return Column(
      children: [
        const TitleHeader(),
        const Header(initialIndex: 1),
        Expanded(
          child: InfiniteScrollGrid(
            showLikedOnly: widget.showLikedOnly,
            crossAxisCount: 2,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            itemBuilder: (photo) => _buildPhotoCard(photo),
          ),
        ),
      ],
    );
  }
}
