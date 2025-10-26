import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html show VideoElement, StyleElement;
import 'dart:ui' as ui show platformViewRegistry;
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../state/app_state.dart';
import '../state/dark_mode_provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'dart:io';
import 'dart:typed_data';
import '../utils/responsive_utils.dart';
import 'home_dashboard_screen.dart';
import 'albums_screen.dart';
import 'feed_screen.dart';
import 'dm_inbox_screen.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import '../utils/platform_detector.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'dart:math';
import 'package:flutter/widgets.dart' show HtmlElementView;

class PostScreen extends StatefulWidget {
  final bool shouldLoadPosts;
  
  const PostScreen({
    super.key,
    this.shouldLoadPosts = false,
  });

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final List<PostModel> _posts = [];
  bool _isLoading = false;
  final Map<String, String> _usernames = {};
  final Map<String, String?> _avatarUrls = {}; // Cache for avatar URLs
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;
  
  // Media upload state
  XFile? _selectedMedia;
  String? _mediaType; // 'image' or 'video'
  bool _isUploading = false;
  String? _uploadedThumbnailUrl; // Store thumbnail URL temporarily

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Log platform information for debugging
    PlatformDetector.logPlatformInfo();
    
    // Load posts when screen is mounted
    _loadPosts();
    _loadUsernames();
    
    // Listen to AppState changes to clear avatar cache when profile pictures are updated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addListener(_onAppStateChanged);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Remove listener to prevent memory leaks
    final appState = Provider.of<AppState>(context, listen: false);
    appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    // Clear avatar cache when AppState changes (profile pictures updated)
    if (mounted) {
      setState(() {
        _avatarUrls.clear();
      });
    }
  }


  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  // Simple refresh method
  Future<void> _refreshPosts() async {
    print('DEBUG: Manual refresh triggered');
    await _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      if (!mounted) return;
      
      print('🔄 Loading posts with pagination...');
      setState(() => _isLoading = true);

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('❌ No authenticated user found');
        setState(() => _isLoading = false);
        return;
      }

      // Reset pagination state
      _lastDocument = null;
      _hasMoreData = true;

      // Load first page of posts
      final loadedPosts = await _loadPostsPage(userId, resetPagination: true);

      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(loadedPosts);
        });
        print('✅ Loaded ${loadedPosts.length} posts (Page 1)');
      }
    } catch (e) {
      print('❌ Error loading posts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final newPosts = await _loadPostsPage(userId, resetPagination: false);
      
      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
        });
        print('✅ Loaded ${newPosts.length} more posts');
      }
    } catch (e) {
      print('❌ Error loading more posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<List<CommentModel>> _loadCommentsForPost(String postId) async {
    try {
      final commentsQuery = await FirestoreService.comments
          .where('postId', isEqualTo: postId)
          .get();
      
      final comments = commentsQuery.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] is Timestamp 
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0);
        
        return CommentModel(
          id: doc.id,
          userId: data['userId'] ?? '',
          content: data['content'] ?? '',
          timestamp: timestamp,
          imageUrl: data['imageUrl'],
        );
      }).toList();
      
      // Sort comments by timestamp manually
      comments.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      return comments;
    } catch (e) {
      print('Error loading comments for post $postId: $e');
      return [];
    }
  }

  Future<List<PostModel>> _loadPostsPage(String userId, {required bool resetPagination}) async {
    const int pageSize = 10;
    
    if (resetPagination) {
      _lastDocument = null;
      _hasMoreData = true;
    }

    if (!_hasMoreData) return [];

    // Get follow status for current user
    List<String> followedUserIds = [];
    try {
      followedUserIds = await FirestoreService.getFollowedUserIds(userId);
    } catch (e) {
      print('DEBUG: Could not fetch follow status: $e');
      followedUserIds = [];
    }

    // Get posts with pagination
    Query query = FirestoreService.posts
        .orderBy('timestamp', descending: true)
        .limit(pageSize);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final postsQuery = await query.get();
    
    if (postsQuery.docs.isEmpty) {
      _hasMoreData = false;
      return [];
    }

    _lastDocument = postsQuery.docs.last;
    _hasMoreData = postsQuery.docs.length == pageSize;

    // Process posts
    final List<PostModel> loadedPosts = [];
    
    for (var doc in postsQuery.docs) {
      if (!mounted) return loadedPosts;
      
      try {
        final data = doc.data() as Map<String, dynamic>;
        final postId = doc.id;
        final postUserId = data['userId'] ?? '';
        
        // Check if current user is following the post author
        final isFollowing = followedUserIds.contains(postUserId);

        // Create post model
        final postTimestamp = data['timestamp'] is Timestamp 
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0);
        
        // Load comments for this post
        final comments = await _loadCommentsForPost(postId);
        
        final post = PostModel(
          id: postId,
          userId: postUserId,
          content: data['content'] ?? '[No content]',
          timestamp: postTimestamp,
          imageUrl: data['imageUrl'],
          videoUrl: data['videoUrl'],
          thumbnailUrl: data['thumbnailUrl'],
          mediaType: data['mediaType'],
          isLiked: false, // Will be updated later if needed
          likeCount: 0,   // Will be updated later if needed
          comments: comments,
          isFollowing: isFollowing,
        );
        loadedPosts.add(post);
      } catch (e) {
        print('DEBUG: Error processing post: $e');
      }
    }

    // Sort posts by timestamp (newest first)
    loadedPosts.sort((a, b) {
      return b.timestamp.compareTo(a.timestamp);
    });

    return loadedPosts;
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (image != null && mounted) {
        setState(() {
          _selectedMedia = image;
          _mediaType = 'image';
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
      );
      
      if (video != null) {
        print('📹 Video selected: ${video.name} (${video.path})');
        print('📹 Video extension: ${video.path.split('.').last}');
        print('📹 Video size: ${video.length()} bytes');
        
        // Check video duration (max 15 seconds for short videos)
        if (PlatformDetector.isMobile) {
          // Only use VideoCompress on mobile platforms
          try {
            final videoInfo = await VideoCompress.getMediaInfo(video.path);
            print('📹 Video duration: ${videoInfo.duration} seconds');
            print('📹 Video file size: ${videoInfo.filesize} bytes');
            print('📹 Video width: ${videoInfo.width}, height: ${videoInfo.height}');
            
            if (videoInfo.duration != null && videoInfo.duration! > 15) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Videos must be 15 seconds or less')),
                );
              }
              return;
            }
            
            // Check file size - reject files > 20MB
            if (videoInfo.filesize != null && videoInfo.filesize! > 20 * 1024 * 1024) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Videos must be 20MB or less')),
                );
              }
              return;
            }
            
            // Check resolution - warn if too high
            if ((videoInfo.width != null && videoInfo.width! > 1920) || 
                (videoInfo.height != null && videoInfo.height! > 1080)) {
              print('⚠️ Video resolution is high: ${videoInfo.width}x${videoInfo.height}');
              print('⚠️ Will be compressed to max 720p');
            }
          } catch (e) {
            print('📹 Could not get video info: $e');
            // Continue even if we can't get video info
          }
        }
        
        if (mounted) {
          setState(() {
            _selectedMedia = video;
            _mediaType = 'video';
          });
        }
      }
    } catch (e) {
      print('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: ${e.toString()}')),
        );
      }
    }
  }

  Future<Uint8List> _compressImage(XFile imageFile) async {
    try {
      if (PlatformDetector.isWeb) {
        // On web, just read the file as bytes
        return await imageFile.readAsBytes();
      }
      
      // On mobile, compress the image
      final file = File(imageFile.path);
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      
      if (result != null) {
        return result;
      }
      // Fallback: read original file
      return await imageFile.readAsBytes();
    } catch (e) {
      print('Error compressing image: $e');
      // Fallback: read original file
      return await imageFile.readAsBytes();
    }
  }

  Future<String?> _generateVideoThumbnail(File videoFile) async {
    try {
      print('📹 Generating thumbnail from video...');
      
      // Use video_compress to generate thumbnail
      final thumbnail = await VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: 85,
        position: -1, // -1 means from the middle of the video
      );
      
      if (thumbnail != null) {
        print('📹 Thumbnail generated successfully');
        return thumbnail.path;
      } else {
        print('📹 Failed to generate thumbnail');
        return null;
      }
    } catch (e) {
      print('📹 Error generating thumbnail: $e');
      return null;
    }
  }

  Future<String> _uploadVideoThumbnail(String userId, String thumbnailPath) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbnailId = '$timestamp';
      
      final ref = FirebaseStorage.instance
          .ref()
          .child('post_thumbnails')
          .child(userId)
          .child('$thumbnailId.jpg');
      
      final file = File(thumbnailPath);
      final thumbnailData = await file.readAsBytes();
      
      await ref.putData(
        thumbnailData,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=7776000', // 90 days cache for better CDN efficiency
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toString(),
          },
        ),
      );
      
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading thumbnail: $e');
      rethrow;
    }
  }

  Future<String> _uploadMedia(String userId, XFile mediaFile, String mediaType) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final mediaId = '$timestamp';
      Reference ref;
      
      if (mediaType == 'image') {
        ref = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child(userId)
            .child('$mediaId.jpg');
        
        final compressedData = await _compressImage(mediaFile);
        
        await ref.putData(
          compressedData,
          SettableMetadata(
            contentType: 'image/jpeg',
            cacheControl: 'public, max-age=7776000', // 90 days cache for better CDN efficiency
            customMetadata: {
              'userId': userId,
              'uploadedAt': DateTime.now().toString(),
            },
          ),
        );
      } else { // video
        // Always store videos as MP4 for best compression and compatibility
        // Accept any input format and convert to optimized MP4
        String originalExtension = 'mp4'; // Default
        if (PlatformDetector.isWeb) {
          // On web, get extension from file name
          originalExtension = mediaFile.name.split('.').last.toLowerCase();
        } else {
          originalExtension = mediaFile.path.split('.').last.toLowerCase();
        }
        
        // Validate extension
        if (!['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(originalExtension)) {
          originalExtension = 'mp4';
        }
        
        print('📹 Original video format: $originalExtension');
        
        ref = FirebaseStorage.instance
            .ref()
            .child('post_videos')
            .child(userId)
            .child('$mediaId.mp4');
        
        if (PlatformDetector.isWeb || PlatformDetector.isPWA) {
          // On web/PWA, we can't compress videos, so upload as-is
          // Try to upload as MP4 if it already is, otherwise upload original
          print('📹 Uploading video from ${PlatformDetector.isPWA ? "PWA" : "web"} without compression');
          final bytes = await mediaFile.readAsBytes();
          
          // Check file size - reject files > 20MB for web uploads
          if (bytes.length > 20 * 1024 * 1024) {
            print('❌ Video file too large: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
            throw Exception('Videos must be 20MB or less');
          }
          
          String contentType = 'video/mp4';
          if (originalExtension == 'mov') {
            contentType = 'video/quicktime';
          } else if (originalExtension == 'avi') {
            contentType = 'video/x-msvideo';
          } else if (originalExtension == 'webm') {
            contentType = 'video/webm';
          }
          
          await ref.putData(
            bytes,
            SettableMetadata(
              contentType: contentType,
              cacheControl: 'public, max-age=7776000', // 90 days cache for better CDN efficiency for web videos too
              customMetadata: {
                'userId': userId,
                'uploadedAt': DateTime.now().toString(),
                'originalFormat': originalExtension,
              },
            ),
          );
        } else {
              // On mobile, always compress to optimized MP4 with bitrate cap
              try {
                print('📹 Compressing video to optimized MP4 with bitrate cap...');
                
                final info = await VideoCompress.compressVideo(
                  mediaFile.path,
                  quality: VideoQuality.MediumQuality, // Balanced quality/size (~2-3 Mbps target)
                  deleteOrigin: false,
                  includeAudio: true,
                  frameRate: 30, // Limit to 30fps
                  // Note: video_compress MediumQuality targets ~2-3 Mbps bitrate
                  // Resolution will be capped by the Quality setting
                );
            
            if (info != null && info.path != null) {
              print('📹 Compression successful!');
              print('📹 Original size: ${(await File(mediaFile.path).length() / 1024 / 1024).toStringAsFixed(2)} MB');
              print('📹 Compressed size: ${(info.filesize != null ? info.filesize! / 1024 / 1024 : 0).toStringAsFixed(2)} MB');
              print('📹 Resolution: ${info.width}x${info.height}');
              print('📹 Duration: ${info.duration} seconds');
              
              final compressedFile = File(info.path!);
              
              // Upload compressed video with cache headers for optimization
              await ref.putFile(
                compressedFile,
                SettableMetadata(
                  contentType: 'video/mp4',
                  cacheControl: 'public, max-age=7776000', // 90 days cache for better CDN efficiency
                  customMetadata: {
                    'userId': userId,
                    'uploadedAt': DateTime.now().toString(),
                    'originalFormat': originalExtension,
                    'compressed': 'true',
                    'width': info.width.toString(),
                    'height': info.height.toString(),
                    'duration': info.duration.toString(),
                  },
                ),
              );
              
              print('📹 Video uploaded with 30-day cache header');
              
              // Get video URL first
              final videoUrl = await ref.getDownloadURL();
              
              // Generate and upload thumbnail
              final thumbnailPath = await _generateVideoThumbnail(compressedFile);
              if (thumbnailPath != null) {
                final thumbnailUrl = await _uploadVideoThumbnail(userId, thumbnailPath);
                print('📹 Thumbnail generated and uploaded: $thumbnailUrl');
                
                // Store thumbnail URL for later use
                if (mounted) {
                  setState(() {
                    _uploadedThumbnailUrl = thumbnailUrl;
                  });
                }
              }
              
              // Clean up compressed video
              await compressedFile.delete();
              
              return videoUrl;
            } else {
              throw Exception('Video compression returned null');
            }
          } catch (e) {
            print('📹 Compression failed: $e');
            print('📹 Uploading original file without compression');
            
            // If compression fails, upload original
            final file = File(mediaFile.path);
            String contentType = 'video/mp4';
            if (originalExtension == 'mov') {
              contentType = 'video/quicktime';
            } else if (originalExtension == 'avi') {
              contentType = 'video/x-msvideo';
            } else if (originalExtension == 'webm') {
              contentType = 'video/webm';
            }
            
            await ref.putFile(
              file,
              SettableMetadata(
                contentType: contentType,
                customMetadata: {
                  'userId': userId,
                  'uploadedAt': DateTime.now().toString(),
                  'originalFormat': originalExtension,
                  'compressed': 'false',
                },
              ),
            );
          }
        }
      }
      
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading media: $e');
      rethrow;
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _isUploading = true;
      });

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final content = _descriptionController.text.trim();
      String? imageUrl;
      String? videoUrl;
      String? thumbnailUrl;
      
      // Upload media if selected
      if (_selectedMedia != null && _mediaType != null) {
        try {
          final url = await _uploadMedia(userId, _selectedMedia!, _mediaType!);
          
          if (_mediaType == 'image') {
            imageUrl = url;
          } else if (_mediaType == 'video') {
            videoUrl = url;
            
            // Get the uploaded thumbnail URL if available
            if (_uploadedThumbnailUrl != null) {
              thumbnailUrl = _uploadedThumbnailUrl;
              print('📹 Using thumbnail URL: $thumbnailUrl');
            }
          }
        } catch (e) {
          print('Error uploading media: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload media: ${e.toString()}')),
            );
          }
          return;
        }
      }

      // Firestore: Create post
      await FirestoreService.posts.add({
        'userId': userId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'mediaType': _mediaType,
      });

      _descriptionController.clear();
      if (mounted) {
        setState(() {
          _selectedMedia = null;
          _mediaType = null;
          _uploadedThumbnailUrl = null; // Reset thumbnail
        });
      }
      
      if (mounted) {
        await _loadPosts(); // Reload posts
      }

    } catch (e) {
      print('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _toggleLike(PostModel post) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Optimistic update
      if (mounted) {
      setState(() {
        post.isLiked = !post.isLiked;
        post.likeCount += post.isLiked ? 1 : -1;
      });
      }

      // Firestore: Toggle like
      if (post.isLiked) {
        await FirestoreService.likes.add({
          'postId': post.id,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Find and delete the like document
        final likeQuery = await FirestoreService.likes
            .where('postId', isEqualTo: post.id)
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
        post.isLiked = !post.isLiked;
        post.likeCount += post.isLiked ? 1 : -1;
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

  Future<void> _toggleFollow(PostModel post) async {
    // Store the original state for potential rollback
    final originalFollowingState = post.isFollowing;
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Don't allow following yourself
      if (userId == post.userId) return;
      
      // Optimistic update - immediately change the UI for ALL posts from this user
      if (mounted) {
        setState(() {
          // Update the clicked post
          post.isFollowing = !post.isFollowing;
          
          // Update ALL posts from the same user
          for (int i = 0; i < _posts.length; i++) {
            if (_posts[i].userId == post.userId) {
              _posts[i].isFollowing = post.isFollowing;
            }
          }
        });

      }

      // Firestore: Toggle follow
      try {
        if (post.isFollowing) {
          await FirestoreService.followUser(userId, post.userId);
  
        } else {
          await FirestoreService.unfollowUser(userId, post.userId);
  
        }
        
        // Update the following users count in the UI
        setState(() {});
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(post.isFollowing ? 'Now following this user!' : 'Unfollowed this user'),
              backgroundColor: post.isFollowing ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {

        // If follow operation fails, revert the UI state for ALL posts from this user
        if (mounted) {
          setState(() {
            // Revert the clicked post
            post.isFollowing = originalFollowingState;
            
            // Revert ALL posts from the same user
            for (int i = 0; i < _posts.length; i++) {
              if (_posts[i].userId == post.userId) {
                _posts[i].isFollowing = originalFollowingState;
              }
            }
          });
        }
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update follow status. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

    } catch (e) {
      // Revert on error for ALL posts from this user
      if (mounted) {
        setState(() {
          // Revert the clicked post
          post.isFollowing = originalFollowingState;
          
          // Revert ALL posts from the same user
          for (int i = 0; i < _posts.length; i++) {
            if (_posts[i].userId == post.userId) {
              _posts[i].isFollowing = originalFollowingState;
            }
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deletePost(PostModel post) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId != post.userId) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: const Text(
            'Delete Post',
            style: TextStyle(color: AppColors.titleText),
          ),
          content: Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
            style: const TextStyle(color: AppColors.titleText),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown,
              ),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        // Delete likes for this post
        final likesQuery = await FirestoreService.likes
            .where('postId', isEqualTo: post.id)
            .get();

        // Delete comments for this post
        final commentsQuery = await FirestoreService.comments
            .where('postId', isEqualTo: post.id)
            .get();

        // Delete post document and related data
        final batch = FirebaseFirestore.instance.batch();
        
        for (var likeDoc in likesQuery.docs) {
          batch.delete(likeDoc.reference);
        }
        
        for (var commentDoc in commentsQuery.docs) {
          batch.delete(commentDoc.reference);
        }
        
        batch.delete(FirestoreService.posts.doc(post.id));
        
        await batch.commit();

        Navigator.pop(context); // Hide loading indicator
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
          await _loadPosts(); // Reload posts to update the UI
        }
      } catch (e) {
        Navigator.pop(context); // Hide loading indicator
        print('Error deleting post: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete post: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _showCommentDialog(PostModel post) {
    final commentController = TextEditingController();
    final appState = Provider.of<AppState>(context, listen: false);
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppColors.pillShape,
          ),
          title: const Text(
            'Add Comment',
            style: TextStyle(color: Colors.brown),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: commentController,
                    style: TextStyle(color: Colors.brown),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                        borderSide: BorderSide(color: Colors.brown),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Image upload section
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.brown),
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                            maxWidth: 1024,
                            maxHeight: 1024,
                          );
                          if (image != null) {
                            setDialogState(() {
                              selectedImage = image;
                            });
                          }
                        },
                      ),
                      const Text(
                        'Add Image',
                        style: TextStyle(color: Colors.brown),
                      ),
                      const Spacer(),
                      if (selectedImage != null)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setDialogState(() {
                              selectedImage = null;
                            });
                          },
                        ),
                    ],
                  ),
                  // Show selected image preview
                  if (selectedImage != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                              child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: PlatformDetector.isWeb || PlatformDetector.isPWA
                                ? FutureBuilder<Uint8List>(
                                    future: selectedImage!.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        try {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(Icons.image, size: 64),
                                              );
                                            },
                                          );
                                        } catch (e) {
                                          return const Center(
                                            child: Icon(Icons.image, size: 64),
                                          );
                                        }
                                      } else {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                    },
                                  )
                          : Image.file(
                              File(selectedImage!.path),
                              fit: BoxFit.cover,
                            ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (post.comments.isNotEmpty) ...[
                    const Text(
                      'Comments:',
                      style: TextStyle(
                        color: Colors.brown,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: post.comments.length,
                        itemBuilder: (context, index) {
                          final comment = post.comments[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildUserAvatar(comment.userId),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      FutureBuilder<String?>(
                                        future: appState.fetchUsername(comment.userId),
                                        builder: (context, snapshot) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: '${snapshot.data ?? 'Loading...'}: ',
                                                      style: const TextStyle(
                                                        color: Colors.brown,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: comment.content,
                                                      style: const TextStyle(color: Colors.brown),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Show image if comment has one
                                              if (comment.imageUrl != null) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  height: 120,
                                                  width: 120,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: Colors.grey[300]!),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.network(
                                                      comment.imageUrl!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Container(
                                                          color: Colors.grey[200],
                                                          child: const Icon(
                                                            Icons.error,
                                                            color: Colors.grey,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatTimestamp(comment.timestamp),
                                        style: TextStyle(
                                          color: Colors.brown[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown,
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (commentController.text.trim().isNotEmpty || selectedImage != null) {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  );
                  
                  await _addComment(post, commentController.text.trim(), imageFile: selectedImage);
                  
                  // Hide loading indicator and close dialog
                  Navigator.pop(context); // Close loading indicator
                  Navigator.pop(context); // Close comment dialog
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.brown,
              ),
              child: const Text('Comment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addComment(PostModel post, String content, {XFile? imageFile}) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Ensure we have the username for the commenter
      await _fetchUsername(userId);

      String? imageUrl;
      
      // Upload image if provided
      if (imageFile != null) {
        try {
          final String commentImageId = DateTime.now().millisecondsSinceEpoch.toString();
          final Reference ref = FirebaseStorage.instance
              .ref()
              .child('comment_images')
              .child(userId)
              .child(commentImageId);
          
          if (PlatformDetector.isWeb || PlatformDetector.isPWA) {
            final bytes = await imageFile.readAsBytes();
            await ref.putData(
              bytes,
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'userId': userId,
                  'uploadedAt': DateTime.now().toString(),
                },
              ),
            );
          } else {
            await ref.putFile(
              File(imageFile.path),
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'userId': userId,
                  'uploadedAt': DateTime.now().toString(),
                },
              ),
            );
          }
          
          imageUrl = await ref.getDownloadURL();
        } catch (e) {
          print('Error uploading comment image: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload image: ${e.toString()}')),
            );
          }
          return;
        }
      }

      // Firestore: Add comment
      final commentDoc = await FirestoreService.comments.add({
        'postId': post.id,
        'userId': userId,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'imageUrl': imageUrl,
      });

      // Optimistic update
      final newComment = CommentModel(
        id: commentDoc.id,
        userId: userId,
        content: content,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
      );

      if (mounted) {
        setState(() {
          post.comments.add(newComment);
        });
      }

    } catch (e) {
      print('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: ${e.toString()}')),
        );
      }
    }
  }



  Future<void> _fetchUsername(String userId) async {
    if (_usernames.containsKey(userId)) return;

    try {
      // Firestore: Get username
      final userDoc = await FirestoreService.users.doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        if (data != null) {
          final username = data['username'] ?? 'Unknown User';
          if (mounted) {
          setState(() {
            _usernames[userId] = username;
          });
          }
        }
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  Future<void> _loadUsernames() async {
    try {
      // Firestore: Get all users
      try {
      final usersQuery = await FirestoreService.users.get();

      for (var doc in usersQuery.docs) {
          try {
        final data = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        
        // First try to get username from the root level
        String? username = data['username'];
        
        // If not found, try to get it from the profile
        if (username == null && data['profile'] is Map) {
          final profile = data['profile'];
          username = profile['username'] ?? 
                     profile['displayName'] ?? 
                     'Unknown User';
            }
            
            // If still not found, try displayName directly
            if (username == null) {
              username = data['displayName'] ?? 'Unknown User';
            }
            
            // If still not found, use Unknown User
            _usernames[userId] = username ?? 'Unknown User';
          } catch (e) {
            // Continue processing other users if one fails
          }
        }
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        // Handle error silently
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _fetchUsernamesBatch(Set<String> userIds) async {
    try {
      // Get all users in one query
      final usersQuery = await FirestoreService.users.get();
      
      for (var doc in usersQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        
        if (userIds.contains(userId)) {
          // First try to get username from the root level
          String? username = data['username'];
          
          // If not found, try to get it from the profile
          if (username == null && data['profile'] is Map) {
            final profile = data['profile'];
            username = profile['username'] ?? 
                       profile['displayName'] ?? 
                       'Unknown User';
          }
          
          // If still not found, try displayName directly
          if (username == null) {
            username = data['displayName'] ?? 'Unknown User';
          }
        
          // If still not found, use Unknown User
          _usernames[userId] = username ?? 'Unknown User';
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<String?> _getAvatarUrl(String userId) async {
    if (_avatarUrls.containsKey(userId)) {
      return _avatarUrls[userId];
    }
    
    try {
      // First check AppState for cached profile picture
      final appState = Provider.of<AppState>(context, listen: false);
      final cachedUrl = appState.getProfilePicture(userId);
      
      if (cachedUrl != null) {
        if (mounted) {
          setState(() {
            _avatarUrls[userId] = cachedUrl;
          });
        }
        return cachedUrl;
      }
      
      // If not in AppState cache, get from Firestore
      final url = await FirestoreService.getUserPhotoUrl(userId);
      
      // Cache in AppState for future use
      appState.updateProfilePicture(userId, url);
      
      if (mounted) {
        setState(() {
          _avatarUrls[userId] = url;
        });
      }
      return url;
    } catch (e) {
      print('Error fetching avatar for user $userId: $e');
      return null;
    }
  }

  Widget _buildUserAvatar(String userId) {
    return FutureBuilder<String?>(
      future: _getAvatarUrl(userId),
      builder: (context, snapshot) {
        final avatarUrl = snapshot.data;
        
        // Check if it's a network URL (real photo) or asset/default
        if (avatarUrl == null || avatarUrl.isEmpty || !avatarUrl.startsWith('http')) {
          // No photo or asset path - show letter avatar
          return FutureBuilder<String?>(
            future: Provider.of<AppState>(context, listen: false).fetchUsername(userId),
            builder: (context, usernameSnapshot) {
              final username = usernameSnapshot.data ?? 'User';
              return _buildLetterAvatar(username);
            },
          );
        }

        // Show network image with proper error handling
        return CircleAvatar(
          radius: 12,
          backgroundImage: NetworkImage(avatarUrl),
          onBackgroundImageError: (exception, stackTrace) {
            // Handle image loading errors by showing letter avatar
            print('Post avatar image failed to load: $avatarUrl, error: $exception');
            if (mounted) {
              // Use post-frame callback to avoid calling setState during paint
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _avatarUrls[userId] = null;
                  });
                }
              });
            }
          },
          child: null, // Remove any child to let background image show
        );
      },
    );
  }

  Widget _buildLetterAvatar(String name) {
    // Get the first letter of the name, fallback to '?' if empty
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    // Generate a consistent color based on the name
    final color = _getColorFromName(name);
    
    return CircleAvatar(
      radius: 12,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Color _getColorFromName(String name) {
    // Generate a consistent color based on the name
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.brown,
      Colors.red,
      Colors.cyan,
    ];
    
    // Use the first character's ASCII value to pick a color
    final index = name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final postWidth = screenWidth - 32;
    final isWideScreen = ResponsiveUtils.isWideScreen(context);
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);

    print('📝 PostScreen: build() called - isDarkMode: ${darkModeProvider.isDarkMode}');

    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: darkModeProvider.isDarkMode 
            ? const BoxDecoration(
                color: AppColors.darkBackground,
              )
            : const BoxDecoration(
                gradient: AppColors.mainGradient,
              ),
        child: SafeArea(
          child: isWideScreen
              ? _buildDesktopLayout(context, appState)
              : _buildMobileLayout(context, appState, postWidth),
        ),
      ),
      bottomNavigationBar: isWideScreen ? null : _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    return Container(
      decoration: BoxDecoration(
        color: darkModeProvider.isDarkMode ? AppColors.darkBackground : Colors.white,
        border: Border(
          top: BorderSide(
            color: darkModeProvider.isDarkMode ? AppColors.darkCardBorder : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: darkModeProvider.isDarkMode ? AppColors.darkBackground : Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: darkModeProvider.isDarkMode ? AppColors.darkText : AppColors.titleText,
        unselectedItemColor: darkModeProvider.isDarkMode ? AppColors.darkTextSecondary : Colors.grey[600],
        currentIndex: 1, // Post screen index
        onTap: (index) {
          // Handle navigation based on selected index
          switch (index) {
            case 0:
              // Home - navigate to HomeDashboardScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomeDashboardScreen(isCurrentUser: true),
                ),
              );
              break;
            case 1:
              // Post - stay on current screen (PostScreen)
              break;
            case 2:
              // Albums - navigate to AlbumsScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlbumsScreen(),
                ),
              );
              break;
            case 3:
              // Feed - navigate to FeedScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const FeedScreen(),
                ),
              );
              break;
            case 4:
              // Messages - navigate to DMInboxScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const DMInboxScreen(),
                ),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.create),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Albums',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rss_feed),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, AppState appState) {
    return Column(
      children: [
        const TitleHeader(),
        const Header(initialIndex: 0),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Post creation form
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0, right: 16.0),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF8E1), // Light cream
                              Color(0xFFFFE0B2), // Light orange
                              Color(0xFFFFCC80), // Medium orange
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Create Post',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.titleText,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildPostCreationForm(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Right side - Posts feed
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0),
                    child: _buildPostsFeed(context, appState, null),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, AppState appState, double postWidth) {
    return Column(
      children: [
        const TitleHeader(),
        const Header(initialIndex: 0),
        
        // Fixed Post Creation Form
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  width: postWidth,
                  decoration: BoxDecoration(
                    gradient: AppColors.inputGradient,
                    borderRadius: AppColors.pillShape,
                  ),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'What\'s happening in the ReptiWorld?',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppColors.pillShape,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a Post';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // Media picker buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.brown),
                      onPressed: _isLoading ? null : _pickImage,
                      tooltip: 'Add Image',
                    ),
                    IconButton(
                      icon: const Icon(Icons.videocam, color: Colors.brown),
                      onPressed: _isLoading ? null : _pickVideo,
                      tooltip: 'Add Video',
                    ),
                    if (_selectedMedia != null)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _selectedMedia = null;
                            _mediaType = null;
                          });
                        },
                        tooltip: 'Remove Media',
                      ),
                  ],
                ),
                // Media preview
                if (_selectedMedia != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _mediaType == 'image'
                          ? (PlatformDetector.isWeb || PlatformDetector.isPWA
                              ? FutureBuilder<Uint8List>(
                                  future: _selectedMedia!.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      final bytes = snapshot.data!;
                                      // Use Image.memory with proper error handling
                                      return Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Image preview error: $error');
                                          // If image decoding fails, show a nice placeholder
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.blue[100]!,
                                                  Colors.blue[200]!,
                                                ],
                                              ),
                                            ),
                                            child: const Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.image, size: 64, color: Colors.white),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Image Selected',
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                )
                              : Image.file(
                                  File(_selectedMedia!.path),
                                  fit: BoxFit.cover,
                                ))
                          : ((PlatformDetector.isWeb || PlatformDetector.isPWA)
                              ? Container(
                                  // For web/PWA, show play icon for videos
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.brown[700]!,
                                        Colors.brown[900]!,
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.play_circle_outline, size: 80, color: Colors.white),
                                        SizedBox(height: 16),
                                        Text(
                                          'Video Selected',
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Tap to upload',
                                          style: TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : FutureBuilder<String>(
                                  future: Future.value(_selectedMedia!.path),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.file(
                                            File(_selectedMedia!.path),
                                            fit: BoxFit.cover,
                                          ),
                                          const Icon(Icons.play_circle_outline,
                                              size: 64, color: Colors.white),
                                        ],
                                      );
                                    }
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                )),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _isLoading
                    ? (_isUploading 
                        ? const Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Uploading media...'),
                            ],
                          )
                        : const CircularProgressIndicator())
                    : SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: ElevatedButton(
                          onPressed: _createPost,
                          style: AppColors.pillButtonStyle,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppColors.loginGradient,
                              borderRadius: AppColors.pillShape,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              alignment: Alignment.center,
                              child: const Text(
                                'Create Post',
                                style: TextStyle(
                                  color: AppColors.buttonText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),

        // Scrollable Posts List
        Expanded(
          child: _buildPostsFeed(context, appState, postWidth),
        ),
      ],
    );
  }

  Widget _buildPostCreationForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.inputGradient,
              borderRadius: AppColors.pillShape,
            ),
            child: TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'What\'s happening in the ReptiWorld?',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: AppColors.pillShape,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppColors.pillShape,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppColors.pillShape,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a Post';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),
          // Media picker buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.image, color: Colors.brown),
                onPressed: _isLoading ? null : _pickImage,
                tooltip: 'Add Image',
              ),
              IconButton(
                icon: const Icon(Icons.videocam, color: Colors.brown),
                onPressed: _isLoading ? null : _pickVideo,
                tooltip: 'Add Video',
              ),
              if (_selectedMedia != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedMedia = null;
                      _mediaType = null;
                    });
                  },
                  tooltip: 'Remove Media',
                ),
            ],
          ),
          // Media preview
          if (_selectedMedia != null) ...[
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _mediaType == 'image'
                    ? (PlatformDetector.isWeb || PlatformDetector.isPWA
                        ? FutureBuilder<Uint8List>(
                            future: _selectedMedia!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final bytes = snapshot.data!;
                                // Use Image.memory with proper error handling
                                return Image.memory(
                                  bytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Image preview error: $error');
                                    // If image decoding fails, show a nice placeholder
                                    return Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue[100]!,
                                            Colors.blue[200]!,
                                          ],
                                        ),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image, size: 64, color: Colors.white),
                                          SizedBox(height: 8),
                                          Text(
                                            'Image Selected',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              }
                              return const Center(child: CircularProgressIndicator());
                            },
                          )
                        : Image.file(
                            File(_selectedMedia!.path),
                            fit: BoxFit.cover,
                          ))
                            : ((PlatformDetector.isWeb || PlatformDetector.isPWA)
                                ? Container(
                                    // For web/PWA, show play icon since we can't extract thumbnail from video file
                                    color: Colors.black45,
                            child: const Center(
                              child: Icon(Icons.play_circle_outline, size: 100, color: Colors.white),
                            ),
                          )
                        : FutureBuilder<String>(
                            future: Future.value(_selectedMedia!.path),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.file(
                                      File(_selectedMedia!.path),
                                      fit: BoxFit.cover,
                                    ),
                                    const Icon(Icons.play_circle_outline,
                                        size: 64, color: Colors.white),
                                  ],
                                );
                              }
                              return const Center(child: CircularProgressIndicator());
                            },
                          )),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _isLoading
              ? (_isUploading 
                  ? const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Uploading media...'),
                      ],
                    )
                  : const CircularProgressIndicator())
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _createPost,
                    style: AppColors.pillButtonStyle,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: AppColors.loginGradient,
                        borderRadius: AppColors.pillShape,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: const Text(
                          'Create Post',
                          style: TextStyle(
                            color: AppColors.buttonText,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPostsFeed(BuildContext context, AppState appState, double? postWidth) {
    return Column(
      children: [
        // Posts list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _posts.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final post = _posts[index];
              return Container(
                width: postWidth,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.inputGradient,
                  borderRadius: AppColors.pillShape,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildUserAvatar(post.userId),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                FutureBuilder<String?>(
                                  future: appState.fetchUsername(post.userId),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? 'Loading...',
                                      style: const TextStyle(
                                        color: Colors.brown,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    );
                                  },
                                ),
                                // Show followed indicator
                                if (post.isFollowing) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green[300]!, width: 1),
                                    ),
                                    child: Text(
                                      'Following',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Follow button - only show if not the current user's post
                          if (FirebaseAuth.instance.currentUser?.uid != post.userId)
                            TextButton(
                                  onPressed: () => _toggleFollow(post),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    backgroundColor: post.isFollowing 
                                        ? Colors.grey[300] 
                                        : Colors.brown[100],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    post.isFollowing ? 'Following' : 'Follow',
                                    style: TextStyle(
                                      color: post.isFollowing 
                                          ? Colors.grey[700] 
                                          : Colors.brown[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                            ),
                          // Delete button - only show for current user's posts
                          if (FirebaseAuth.instance.currentUser?.uid == post.userId)
                            TextButton(
                              onPressed: () => _deletePost(post),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                backgroundColor: Colors.red[100],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.content,
                        style: const TextStyle(
                          color: Colors.brown,
                          fontSize: 16,
                        ),
                      ),
                      // Display media if present
                      if (post.imageUrl != null && post.mediaType == 'image') ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              post.imageUrl!,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error, size: 50),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      if (post.videoUrl != null && post.mediaType == 'video') ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LazyVideoPlayer(
                              videoUrl: post.videoUrl!,
                              thumbnailUrl: post.thumbnailUrl,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              post.isLiked ? Icons.favorite : Icons.favorite_border,
                              color: post.isLiked ? Colors.red : Colors.brown[400],
                            ),
                            onPressed: () => _toggleLike(post),
                          ),
                          Text(
                            '${post.likeCount} likes',
                            style: TextStyle(
                              color: Colors.brown[400],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              Icons.comment_outlined,
                              color: Colors.brown[400],
                            ),
                            onPressed: () => _showCommentDialog(post),
                          ),
                          Text(
                            '${post.comments.length} comments',
                            style: TextStyle(
                              color: Colors.brown[400],
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTimestamp(post.timestamp),
                            style: TextStyle(
                              color: Colors.brown[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Show latest comment if exists
                      if (post.comments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.brown.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildUserAvatar(post.comments.last.userId),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FutureBuilder<String?>(
                                      future: appState.fetchUsername(post.comments.last.userId),
                                      builder: (context, snapshot) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Latest: ${snapshot.data ?? 'Loading...'}: ${post.comments.last.content}',
                                              style: const TextStyle(
                                                color: Colors.brown,
                                                fontSize: 14,
                                              ),
                                            ),
                                            // Show image if latest comment has one
                                            if (post.comments.last.imageUrl != null) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                height: 80,
                                                width: 80,
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey[300]!),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    post.comments.last.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        color: Colors.grey[200],
                                                        child: const Icon(
                                                          Icons.error,
                                                          color: Colors.grey,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimestamp(post.comments.last.timestamp),
                                      style: TextStyle(
                                        color: Colors.brown[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
      return DateFormat('MMM d, y').format(timestamp);
    }
  }
}

// Video player widget for posts
class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const PostVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      print('📹 Initializing video player for: ${widget.videoUrl}');
      
      if (PlatformDetector.isWeb || PlatformDetector.isPWA) {
        // On web/PWA, use basic HTML5 video player instead of video_player
        setState(() {
          _isInitialized = true;
          _hasError = true;
          _errorMessage = 'Web video playback requires HTML5 video element';
        });
        return;
      }
      
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      
      // Add error listener
      _controller!.addListener(_videoListener);
      
      await _controller!.initialize();
      
      if (mounted && !_hasError) {
        setState(() {
          _isInitialized = true;
        });
        print('📹 Video initialized successfully');
      }
    } catch (e) {
      print('📹 Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null) return;
    
    // Check for errors
    if (_controller!.value.hasError) {
      print('📹 Video player error: ${_controller!.value.errorDescription}');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _controller!.value.errorDescription;
        });
      }
    }
    
    // Update playing state
    if (mounted) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || _hasError) return;
    
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            const Text(
              'Video playback error',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _initializeVideo,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (PlatformDetector.isWeb || PlatformDetector.isPWA) {
      // For web/PWA, use HTML video element (basic implementation)
      return Container(
        height: 200,
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_file, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Video available',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // Open video in new tab
                if (mounted) {
                  // For now, just show a message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Video: ${widget.videoUrl}'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: const Text('View Video', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (_controller == null) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          if (!_isPlaying)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_filled,
                size: 64,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

/// Web-specific video player element
/// Uses HTML video element for inline playback
class _WebVideoPlayerElement extends StatefulWidget {
  final String videoUrl;

  const _WebVideoPlayerElement({
    required this.videoUrl,
  });

  @override
  State<_WebVideoPlayerElement> createState() => _WebVideoPlayerElementState();
}

class _WebVideoPlayerElementState extends State<_WebVideoPlayerElement> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'video-player-${widget.videoUrl.hashCode}';
    _registerViewFactory();
  }

  void _registerViewFactory() {
    if (kIsWeb) {
      // Register HTML video element factory for inline playback
      ui.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) {
          // Create HTML video element
          final htmlVideoElement = html.VideoElement()
            ..src = widget.videoUrl
            ..controls = true
            ..autoplay = false
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'contain';
          
          // Add styling
          htmlVideoElement.style.backgroundColor = '#000000';
          
          return htmlVideoElement;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return the platform view that renders the HTML video element
    return Container(
      color: Colors.black,
      child: SizedBox(
        width: double.infinity,
        height: 400,
        child: HtmlElementView(viewType: _viewId),
      ),
    );
  }
}

class _InlineVideoModal extends StatelessWidget {
  final String videoUrl;

  const _InlineVideoModal({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Playing Video',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Video player area
          Expanded(
            child: Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam, size: 80, color: Colors.white70),
                    const SizedBox(height: 16),
                    const Text(
                      'Video Player',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        videoUrl,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Open video in browser as fallback
                        try {
                          final uri = Uri.parse(videoUrl);
                          if (await url_launcher.canLaunchUrl(uri)) {
                            await url_launcher.launchUrl(uri);
                          }
                        } catch (e) {
                          print('Error opening video: $e');
                        }
                      },
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Open in Browser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.brown[700],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// Lazy loading video player - shows thumbnail first, loads video only when user plays
class LazyVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const LazyVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  @override
  State<LazyVideoPlayer> createState() => _LazyVideoPlayerState();
}

class _LazyVideoPlayerState extends State<LazyVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _shouldLoadVideo = false; // Only load video when user taps

  @override
  void initState() {
    super.initState();
    // Don't initialize video yet - wait for user to tap
  }

  void _handleWebVideoTap() {
    // For web, toggle between thumbnail and video player
    if (!_shouldLoadVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    if (_controller != null || _shouldLoadVideo) return;
    
    _shouldLoadVideo = true;
    
    try {
      print('📹 Lazy loading video player for: ${widget.videoUrl}');
      
      if (PlatformDetector.isWeb || PlatformDetector.isPWA) {
        // On web/PWA, we can't use video_player, just show that video is ready
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
        print('📹 Video ready for playback (web)');
        return;
      }
      
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      
      // Add error listener
      _controller!.addListener(_videoListener);
      
      await _controller!.initialize();
      
        if (mounted && !_hasError) {
          setState(() {
            _isInitialized = true;
          });
          print('📹 Video loaded successfully (lazy load)');
          
          // For web, don't auto-play, user will tap to play
          if (!PlatformDetector.isWeb && !PlatformDetector.isPWA) {
            // Auto-play when loaded only on mobile
            _controller!.play();
            setState(() {
              _isPlaying = true;
            });
          }
        }
    } catch (e) {
      print('📹 Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null) return;
    
    // Check for errors
    if (_controller!.value.hasError) {
      print('📹 Video player error: ${_controller!.value.errorDescription}');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _controller!.value.errorDescription;
        });
      }
    }
    
    // Update playing state
    if (mounted) {
      setState(() {
        _isPlaying = _controller!.value.isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_shouldLoadVideo) {
      // First tap - load the video
      _initializeVideo();
      return;
    }
    
    if (_controller == null || _hasError) return;
    
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPlaying = false;
      } else {
        _controller!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show thumbnail until user taps to play
    if (!_shouldLoadVideo) {
      return GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Show thumbnail if available, otherwise show placeholder
            if (widget.thumbnailUrl != null)
              Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.brown[700]!, Colors.brown[900]!],
                      ),
                    ),
                    child: const Center(child: Icon(Icons.videocam, size: 64, color: Colors.white70)),
                  );
                },
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.brown[700]!, Colors.brown[900]!],
                  ),
                ),
                child: const Center(child: Icon(Icons.videocam, size: 64, color: Colors.white70)),
              ),
            // Play button overlay
            Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_filled,
                size: 72,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return GestureDetector(
        onTap: _togglePlayPause,
        child: Container(
          height: 200,
          color: Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              const Text(
                'Video playback error',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _initializeVideo,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Handle web/PWA playback - show inline video player
    if (PlatformDetector.isWeb || PlatformDetector.isPWA) {
      // If video is loaded, show the HTML video player
      if (_shouldLoadVideo && _isInitialized) {
        return Container(
          height: 400,
          constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _WebVideoPlayerElement(videoUrl: widget.videoUrl),
          ),
        );
      }
      
      // Show thumbnail with play button
      return GestureDetector(
        onTap: _handleWebVideoTap,
        child: Container(
          height: 400,
          constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Show thumbnail if available
              if (widget.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.thumbnailUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Icon(Icons.videocam, size: 80, color: Colors.white70),
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(Icons.videocam, size: 80, color: Colors.white70),
                  ),
                ),
              // Play button overlay
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.play_circle_filled,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
              // Control bar at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      const Text(
                        'Tap to play video',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          if (!_isPlaying)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_circle_filled,
                size: 64,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

}