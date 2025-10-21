import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../styles/colors.dart';
import '../utils/responsive_utils.dart';
import '../state/app_state.dart';
import '../state/dark_mode_provider.dart';
import '../services/firestore_service.dart';
import '../services/like_cache_service.dart';
import '../models/photo_data.dart';
import 'post_screen.dart';
import 'albums_screen.dart';
import 'feed_screen.dart';
import 'login_screen.dart';
import 'dm_inbox_screen.dart';
import '../widgets/nav_drawer.dart';

class HomeDashboardScreen extends StatefulWidget {
  final String? userId;
  final bool isCurrentUser;
  
  const HomeDashboardScreen({
    super.key,
    this.userId,
    this.isCurrentUser = true,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _selectedBottomNavIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  int _displayedResultsCount = 20; // Number of results to show initially
  late PageController _pageController;
  int _currentFollowingPage = 0;
  List<Map<String, dynamic>> _followedUsers = [];
  bool _isLoadingFollowedUsers = false;
  bool _isLoadingInProgress = false;
  Timer? _searchTimer;
  
  // PWA-optimized image management
  final Map<String, bool> _imageErrors = {}; // URL -> failed to load
  final Map<String, bool> _imageCache = {}; // URL -> successfully loaded
  final Map<String, String> _imageCacheKeys = {}; // URL -> cache key for service worker
  
  // User profile data
  Map<String, dynamic>? _profileUser;
  bool _isLoadingProfileUser = false;
  
  // User photos data for terrarium
  List<Map<String, dynamic>> _userPhotos = [];
  bool _isLoadingUserPhotos = false;
  bool _hasMorePhotos = true;
  DocumentSnapshot? _lastPhotoDocument;
  
  // Current user data and image picking
  Map<String, dynamic>? _currentUserData;
  bool _isLoadingCurrentUser = false;
  bool _isUploadingProfilePic = false;
  bool _isUploadingBackground = false;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Custom profile phrase
  String? _customPhrase;
  bool _isHoveringPhrase = false;
  
  // Background hover state
  bool _isHoveringBackground = false;
  
  // Profile picture hover state
  bool _isHoveringProfilePic = false;
  
  // Follow status for other users
  bool _isFollowing = false;
  bool _isLoadingFollowStatus = false;
  
  // Get the effective user ID (either provided or current user)
  String? get _effectiveUserId => widget.userId ?? FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _pageController = PageController();
    
    // Initialize authentication state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.initializeUser();
      
      // Load profile user data if viewing another user's profile
      if (!widget.isCurrentUser && widget.userId != null) {
        _loadProfileUser(widget.userId!);
        _loadFollowStatus(widget.userId!);
      } else if (widget.isCurrentUser) {
        // Load current user data for profile picture and background
        _loadCurrentUserData();
      }
      
      // Set loading state immediately to show loading indicator
      setState(() {
        _isLoadingUserPhotos = true;
      });
      
      // Add a delay to ensure Firestore is fully initialized
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _loadFollowedUsers();
          // Load user photos for terrarium for both current user and other users
          if (widget.isCurrentUser) {
            _loadUserPhotos();
          } else if (widget.userId != null) {
            // Load other user's photos for their terrarium
            _loadOtherUserPhotos(widget.userId!);
          }
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh followed users when returning to this screen
    if (mounted && FirebaseAuth.instance.currentUser != null) {
      // Add a small delay to avoid conflicts with other operations
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadFollowedUsers();
          // Refresh photos if it's the current user's dashboard
          if (widget.isCurrentUser) {
            _loadUserPhotos(resetPagination: true);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  // PWA-optimized image loading with service worker integration
  Future<void> _preloadImageForPWA(String imageUrl) async {
    if (_imageCache.containsKey(imageUrl) || _imageErrors.containsKey(imageUrl)) {
      return; // Already processed
    }

    try {
      // Generate cache key for service worker
      final cacheKey = 'avatar_${imageUrl.hashCode}';
      _imageCacheKeys[imageUrl] = cacheKey;

      // Simple preload without precacheImage to avoid conflicts
      final imageProvider = NetworkImage(imageUrl);
      
      // Test if image loads by resolving it
      await imageProvider.resolve(ImageConfiguration.empty);
      
      _imageCache[imageUrl] = true;
      print('✅ PWA Image loaded successfully: ${imageUrl.substring(0, 50)}...');
      
      if (mounted) {
        setState(() {}); // Trigger rebuild
      }
      
      // Store in PWA cache for offline access
      _storeImageInPWACache(imageUrl, cacheKey);
      
    } catch (e) {
      _imageErrors[imageUrl] = true;
      print('❌ PWA Image preload error: $e');
    }
  }

  // Store image in PWA cache for offline access
  void _storeImageInPWACache(String imageUrl, String cacheKey) {
    // This would integrate with service worker for offline caching
    // For now, we'll use Flutter's built-in caching
    print('📱 PWA: Caching image for offline access: $cacheKey');
  }

  // Avatar builder using the same approach as post screen
  Widget _buildPWAAvatar(String? avatarUrl, String name) {
    // Check if it's a network URL (real photo) or asset/default
    if (avatarUrl == null || avatarUrl.isEmpty || !avatarUrl.startsWith('http')) {
      // No photo or asset path - show letter avatar
      return _buildLetterAvatarForSearch(name);
    }

    // Check if this image previously failed
    if (_imageErrors.containsKey(avatarUrl)) {
      return _buildLetterAvatarForSearch(name);
    }

    // Show network image with proper error handling (same as post screen)
    return CircleAvatar(
      radius: 20,
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (exception, stackTrace) {
        // Handle image loading errors by showing letter avatar
        print('Search avatar image failed to load: $avatarUrl, error: $exception');
        if (mounted) {
          // Use post-frame callback to avoid calling setState during paint
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _imageErrors[avatarUrl] = true;
              });
            }
          });
        }
      },
      child: null, // Remove child to let background image show
    );
  }

  // Get Google image proxy URL to bypass CORS
  String _getGoogleImageProxy(String originalUrl) {
    // For now, just return the original URL and let it fail gracefully
    // In production, you'd want to implement a proper image proxy service
    return originalUrl;
  }


  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
        _displayedResultsCount = 20;
      });
      return;
    }

    // Debounce search to avoid too many Firestore calls
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
    setState(() {
      _isSearching = true;
      _showSearchResults = true;
      _displayedResultsCount = 20;
    });
    _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      // Clear previous image errors for fresh attempt
      _imageErrors.clear();
      
      // Get all users and filter client-side for more flexible search
      final usersQuery = await FirestoreService.users.limit(100).get();
      
      final allUsers = <Map<String, dynamic>>[];
      final searchQuery = query.toLowerCase();

      for (final doc in usersQuery.docs) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = doc.id;
          final username = (data['username'] ?? '').toString();
          final displayName = (data['displayName'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          
          // Create a robust display name with fallbacks
          final userDisplayName = displayName.isNotEmpty ? displayName :
                                 username.isNotEmpty ? username :
                                 email.isNotEmpty ? email.split('@')[0] : 'Unknown';
          final photoUrl = data['photoUrl'] ?? data['photoURL'];
          
          // Filter out asset paths, only keep HTTP URLs
          final avatarUrl = (photoUrl != null && photoUrl.startsWith('http')) ? photoUrl : null;
          
          
          
          // Check if user matches search query (more flexible matching)
          final matchesUsername = username.toLowerCase().contains(searchQuery);
          final matchesDisplayName = displayName.toLowerCase().contains(searchQuery);
          final matchesEmail = email.toLowerCase().contains(searchQuery);
          
          if (matchesUsername || matchesDisplayName || matchesEmail) {
            allUsers.add({
              'uid': uid,
              'username': username,
              'displayName': userDisplayName, // Use the robust display name
              'email': email,
              'photoURL': avatarUrl, // Only HTTP URLs or null
            });
          }
        }
      }

      // Sort by relevance (exact matches first, then partial matches)
      allUsers.sort((a, b) {
        final aUsername = a['username'].toString().toLowerCase();
        final bUsername = b['username'].toString().toLowerCase();
        final aDisplayName = a['displayName'].toString().toLowerCase();
        final bDisplayName = b['displayName'].toString().toLowerCase();
        
        final aExactMatch = aUsername == searchQuery || aDisplayName == searchQuery;
        final bExactMatch = bUsername == searchQuery || bDisplayName == searchQuery;
        
        if (aExactMatch && !bExactMatch) return -1;
        if (!aExactMatch && bExactMatch) return 1;
        
        // If both or neither are exact matches, sort alphabetically
        return aUsername.compareTo(bUsername);
      });

      if (mounted) {
        setState(() {
          _searchResults = allUsers;
          _displayedResultsCount = 20.clamp(0, allUsers.length);
          _isSearching = false;
        });
      }
      
      print('✅ Found ${allUsers.length} users matching "$query"');
      
    } catch (e) {
      print('Error searching users: $e');
      if (mounted) {
        setState(() {
          _searchResults = [];
          _displayedResultsCount = 0;
          _isSearching = false;
        });
      }
    }
  }

  void _loadMoreResults() {
    if (_displayedResultsCount < _searchResults.length) {
      setState(() {
        _displayedResultsCount = (_displayedResultsCount + 10).clamp(0, _searchResults.length);
      });
    }
  }


  // Natural comparison function that handles numbers correctly
  int _naturalCompare(String a, String b) {
    final regex = RegExp(r'(\d+|\D+)');
    final aParts = regex.allMatches(a).map((m) => m.group(0)!).toList();
    final bParts = regex.allMatches(b).map((m) => m.group(0)!).toList();
    
    final minLength = aParts.length < bParts.length ? aParts.length : bParts.length;
    
    for (int i = 0; i < minLength; i++) {
      final aPart = aParts[i];
      final bPart = bParts[i];
      
      // Check if both parts are numeric
      final aIsNumeric = RegExp(r'^\d+$').hasMatch(aPart);
      final bIsNumeric = RegExp(r'^\d+$').hasMatch(bPart);
      
      if (aIsNumeric && bIsNumeric) {
        // Compare as numbers
        final aNum = int.parse(aPart);
        final bNum = int.parse(bPart);
        final numCompare = aNum.compareTo(bNum);
        if (numCompare != 0) return numCompare;
      } else {
        // Compare as strings
        final strCompare = aPart.compareTo(bPart);
        if (strCompare != 0) return strCompare;
      }
    }
    
    // If all compared parts are equal, compare by length
    return aParts.length.compareTo(bParts.length);
  }

  Widget _buildSearchAvatar(String? avatarUrl, String name) {
    // Use PWA-optimized avatar builder
    return _buildPWAAvatar(avatarUrl, name);
  }

  Widget _buildLetterAvatarForSearch(String name) {
    // Get the first letter of the name
    final initial = name[0].toUpperCase();
    
    // Generate a consistent color based on the name
    final color = _getColorFromName(name);
    
    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Future<void> _loadCurrentUserData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingCurrentUser = true;
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _currentUserData = null;
            _isLoadingCurrentUser = false;
          });
        }
        return;
      }

      final userDoc = await FirestoreService.users.doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentUserData = userData;
            _customPhrase = userData['customPhrase'] as String?;
            _isLoadingCurrentUser = false;
          });
        }
        print('✅ Loaded current user data');
      } else {
        if (mounted) {
          setState(() {
            _currentUserData = null;
            _isLoadingCurrentUser = false;
          });
        }
        print('❌ Current user document not found');
      }
    } catch (e) {
      print('Error loading current user data: $e');
      if (mounted) {
        setState(() {
          _currentUserData = null;
          _isLoadingCurrentUser = false;
        });
      }
    }
  }

  Future<void> _loadProfileUser(String userId) async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingProfileUser = true;
        });
      }

      final userDoc = await FirestoreService.users.doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _profileUser = userData;
            _isLoadingProfileUser = false;
          });
        }
        print('✅ Loaded profile user data for $userId');
      } else {
        if (mounted) {
          setState(() {
            _profileUser = null;
            _isLoadingProfileUser = false;
          });
        }
        print('❌ User $userId not found');
      }
    } catch (e) {
      print('Error loading profile user $userId: $e');
      if (mounted) {
        setState(() {
          _profileUser = null;
          _isLoadingProfileUser = false;
        });
      }
    }
  }

  Future<void> _loadFollowStatus(String userId) async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingFollowStatus = true;
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _isLoadingFollowStatus = false;
          });
        }
        return;
      }

      // Check if current user is following this user
      final isFollowing = await FirestoreService.isFollowingUser(currentUser.uid, userId);

      if (mounted) {
        setState(() {
          _isFollowing = isFollowing;
          _isLoadingFollowStatus = false;
        });
      }

      print('✅ Follow status loaded: ${_isFollowing ? "Following" : "Not following"} $userId');

    } catch (e) {
      print('Error loading follow status for $userId: $e');
      if (mounted) {
        setState(() {
          _isFollowing = false;
          _isLoadingFollowStatus = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.isCurrentUser || widget.userId == null) return;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Store original state for potential rollback
      final originalFollowingState = _isFollowing;

      // Optimistic update - immediately change the UI
      if (mounted) {
        setState(() {
          _isLoadingFollowStatus = true;
          _isFollowing = !_isFollowing;
        });
      }

      // Firestore: Toggle follow
      try {
        if (_isFollowing) {
          await FirestoreService.followUser(currentUser.uid, widget.userId!);
        } else {
          await FirestoreService.unfollowUser(currentUser.uid, widget.userId!);
        }

        // Show success message
        if (mounted) {
          setState(() {
            _isLoadingFollowStatus = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isFollowing ? 'Now following this user!' : 'Unfollowed this user'),
              backgroundColor: _isFollowing ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // If follow operation fails, revert the UI state
        if (mounted) {
          setState(() {
            _isFollowing = originalFollowingState;
            _isLoadingFollowStatus = false;
          });
        }

        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update follow status. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLoadingFollowStatus = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return;

      if (mounted) {
        setState(() {
          _isUploadingProfilePic = true;
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Read image bytes (works in web/PWA mode)
      final bytes = await image.readAsBytes();

      // Upload to Firebase Storage using putData (works in web/PWA mode)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${currentUser.uid}.jpg');

      final uploadTask = await storageRef.putData(bytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update Firebase Auth photo URL
      await currentUser.updatePhotoURL(downloadUrl);
      await currentUser.reload();

      // Update user document
      await FirestoreService.users.doc(currentUser.uid).update({
        'photoUrl': downloadUrl,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update local data
      if (mounted) {
        setState(() {
          _currentUserData?['photoUrl'] = downloadUrl;
          _isUploadingProfilePic = false;
        });
      }

      // Notify AppState to update profile picture across the app
      final appState = Provider.of<AppState>(context, listen: false);
      appState.updateProfilePicture(currentUser.uid, downloadUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error uploading profile picture: $e');
      if (mounted) {
        setState(() {
          _isUploadingProfilePic = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading profile picture: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateCustomPhrase() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final TextEditingController controller = TextEditingController(text: _customPhrase ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile Phrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add a short and sweet phrase for your profile:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 50, // Keep it short and sweet
              decoration: const InputDecoration(
                hintText: 'e.g., "Patience is a reptile\'s superpower."',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Reset hover state when dialog closes
    if (mounted) {
      setState(() {
        _isHoveringPhrase = false;
      });
    }

    if (result != null && result.isNotEmpty) {
      try {
        // Update in Firestore
        await FirestoreService.users.doc(currentUser.uid).update({
          'customPhrase': result,
          'customPhraseUpdatedAt': FieldValue.serverTimestamp(),
        });

        // Update local state
        if (mounted) {
          setState(() {
            _customPhrase = result;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile phrase updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error updating custom phrase: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile phrase: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadBackgroundImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (image == null) return;

      if (mounted) {
        setState(() {
          _isUploadingBackground = true;
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Read image bytes (works in web/PWA mode)
      final bytes = await image.readAsBytes();

      // Upload to Firebase Storage using putData (works in web/PWA mode)
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_backgrounds')
          .child('${currentUser.uid}.jpg');

      final uploadTask = await storageRef.putData(bytes);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update user document
      await FirestoreService.users.doc(currentUser.uid).update({
        'backgroundUrl': downloadUrl,
        'backgroundUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update local data
      if (mounted) {
        setState(() {
          _currentUserData?['backgroundUrl'] = downloadUrl;
          _isUploadingBackground = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background image updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error uploading background image: $e');
      if (mounted) {
        setState(() {
          _isUploadingBackground = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading background image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUserPhotos({bool resetPagination = false}) async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingUserPhotos = true;
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _userPhotos = [];
            _isLoadingUserPhotos = false;
          });
        }
        return;
      }

      // Reset pagination if requested
      if (resetPagination) {
        _lastPhotoDocument = null;
        _hasMorePhotos = true;
        _userPhotos.clear();
      }

      if (!_hasMorePhotos) {
        if (mounted) {
          setState(() {
            _isLoadingUserPhotos = false;
          });
        }
        return;
      }

      // Build query for user's photos from all sources (albums, binders, notebooks, photos only)
      // Use a simple query without ordering to avoid index requirements
      Query query = FirestoreService.photos
          .where('userId', isEqualTo: currentUser.uid)
          .limit(100); // Get more photos to sort client-side

      // Add pagination if we have a last document
      if (_lastPhotoDocument != null) {
        query = query.startAfterDocument(_lastPhotoDocument!);
      }

      final photosQuery = await query.get();
      
      print('🔍 Firestore query returned ${photosQuery.docs.length} documents');

      if (photosQuery.docs.isEmpty) {
        _hasMorePhotos = false;
        if (mounted) {
          setState(() {
            _isLoadingUserPhotos = false;
          });
        }
        return;
      }

      // Process photos from all sources (albums, binders, notebooks, photos only)
      final List<Map<String, dynamic>> newPhotos = [];
      for (final doc in photosQuery.docs) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          
          // Debug: Print photo data to understand structure
          print('📸 Photo data: ${doc.id}');
          print('   - firebaseUrl: ${data['firebaseUrl']}');
          print('   - url: ${data['url']}');
          print('   - source: ${data['source']}');
          print('   - albumName: ${data['albumName']}');
          
          // Include photos from all sources:
          // - Albums (source: 'albums' or albumName exists)
          // - Binders (source: 'binders' or binderName exists)  
          // - Notebooks (source: 'photosOnly' with notebookName)
          // - Photos Only (source: 'photosOnly' without notebookName)
          final source = data['source'] ?? '';
          final albumName = data['albumName'];
          final binderName = data['binderName'];
          final notebookName = data['notebookName'];
          
          // Get cached like data from photo document
          final likeData = LikeCacheService.getCachedLikeData(data, currentUser.uid);
          
          // Include all photos regardless of source with like data
          newPhotos.add({
            'id': doc.id,
            ...data,
            'source': source,
            'albumName': albumName,
            'binderName': binderName,
            'notebookName': notebookName,
            'isLiked': likeData['isLiked'] as bool,
            'likesCount': likeData['likesCount'] as int,
          });
        }
      }

      // Sort photos by timestamp (newest first) client-side
      newPhotos.sort((a, b) {
        final timestampA = a['timestamp'] ?? 0;
        final timestampB = b['timestamp'] ?? 0;
        return timestampB.compareTo(timestampA); // Descending order (newest first)
      });

      // Take only the first 20 photos for this batch
      final photosToAdd = newPhotos.take(20).toList();
      
      print('📸 Processed ${newPhotos.length} photos, adding ${photosToAdd.length} to display');

      // Update last document for pagination
      _lastPhotoDocument = photosQuery.docs.last;
      _hasMorePhotos = photosQuery.docs.length == 100;

      if (mounted) {
        setState(() {
          if (resetPagination) {
            _userPhotos = photosToAdd;
          } else {
            _userPhotos.addAll(photosToAdd);
          }
          _isLoadingUserPhotos = false;
        });
      }

      print('✅ Loaded ${photosToAdd.length} photos for terrarium (total: ${_userPhotos.length})');

    } catch (e) {
      print('Error loading user photos: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserPhotos = false;
        });
      }
    }
  }

  Future<void> _loadOtherUserPhotos(String userId) async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingUserPhotos = true;
          _userPhotos = []; // Clear previous user's photos immediately
        });
      }

      print('📸 Loading photos for other user: $userId');

      // Query photos for the specific user
      Query query = FirestoreService.photos
          .where('userId', isEqualTo: userId)
          .limit(100); // Get more photos to sort client-side

      final photosQuery = await query.get();
      print('🔍 Firestore query returned ${photosQuery.docs.length} documents');

      final List<Map<String, dynamic>> newPhotos = [];
      for (final doc in photosQuery.docs) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          print('📸 Photo data: ${data['timestamp']}');
          print('   - firebaseUrl: ${data['firebaseUrl']}');
          print('   - url: ${data['url']}');
          print('   - source: ${data['source']}');
          print('   - albumName: ${data['albumName']}');

          // Get cached like data from photo document
          final currentUser = FirebaseAuth.instance.currentUser;
          final likeData = currentUser != null 
              ? LikeCacheService.getCachedLikeData(data, currentUser.uid)
              : {'isLiked': false, 'likesCount': 0};

          // Add source information for display with like data
          newPhotos.add({
            'id': doc.id,
            ...data,
            'sourceLabel': _getSourceLabel(data),
            'sourceColor': _getSourceColor(data),
            'isLiked': likeData['isLiked'] as bool,
            'likesCount': likeData['likesCount'] as int,
          });
        }
      }

      // Sort photos by timestamp (newest first) client-side
      newPhotos.sort((a, b) {
        final timestampA = a['timestamp'] ?? 0;
        final timestampB = b['timestamp'] ?? 0;
        return timestampB.compareTo(timestampA); // Descending order (newest first)
      });

      // Take only the first 20 photos for this batch
      final photosToAdd = newPhotos.take(20).toList();
      
      print('📸 Processed ${newPhotos.length} photos, adding ${photosToAdd.length} to display');

      if (mounted) {
        setState(() {
          _userPhotos = photosToAdd;
          _isLoadingUserPhotos = false;
        });
      }

      print('✅ Loaded ${photosToAdd.length} photos for other user terrarium (total: ${_userPhotos.length})');

    } catch (e) {
      print('Error loading other user photos: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserPhotos = false;
        });
      }
    }
  }

  Future<void> _loadFollowedUsers() async {
    // For now, let's use mock data until Firestore issues are resolved
    // This ensures the UI works while we fix the underlying Firestore problems
    
    try {
      if (mounted) {
        setState(() {
          _isLoadingFollowedUsers = true;
        });
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _followedUsers = [];
            _isLoadingFollowedUsers = false;
          });
        }
        return;
      }

      // Simulate loading delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Load real followed users from Firestore
      // Add a delay to ensure Firestore is fully ready
      await Future.delayed(const Duration(seconds: 1));
      
      final followersQuery = await FirestoreService.followers
          .where('followerId', isEqualTo: currentUser.uid)
          .get();
      
      if (followersQuery.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _followedUsers = [];
            _isLoadingFollowedUsers = false;
          });
        }
        print('✅ No followed users found');
        return;
      }

      // Get user IDs from followers
      final followedUserIds = followersQuery.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['followedUserId'] as String)
          .toList();

      print('✅ Found ${followedUserIds.length} followed user IDs');

      // Fetch user details
      final List<Map<String, dynamic>> followedUsers = [];
      for (final userId in followedUserIds) {
        try {
          final userDoc = await FirestoreService.users.doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            // Get photo URL, but treat asset paths as no photo
            final photoUrl = userData['photoUrl'] ?? userData['photoURL'];
            final avatarUrl = (photoUrl != null && photoUrl.startsWith('http')) 
                ? photoUrl 
                : null; // Treat asset paths and null as no photo
            
            // Get user name with fallbacks (every user should have displayName)
            String userName = userData['displayName']?.toString() ?? 
                             userData['username']?.toString() ?? 
                             userData['email']?.toString().split('@')[0] ?? // Use email prefix as fallback
                             'Unknown';
            
            followedUsers.add({
              'uid': userId,
              'name': userName,
              'username': userData['username'] ?? 'unknown',
              'avatar': avatarUrl ?? '', // Empty string for no photo
            });
          }
        } catch (e) {
          print('Error fetching user $userId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _followedUsers = followedUsers;
          _isLoadingFollowedUsers = false;
        });
        print('✅ Loaded ${followedUsers.length} followed users from Firestore');
      }
      
    } catch (e) {
      print('Error loading followed users: $e');
      if (mounted) {
        setState(() {
          _followedUsers = [];
          _isLoadingFollowedUsers = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check authentication state
    return Consumer2<AppState, DarkModeProvider>(
      builder: (context, appState, darkModeProvider, child) {
        final currentUser = appState.currentUser;
        
        print('🏠 HomeDashboardScreen: build() called - isDarkMode: ${darkModeProvider.isDarkMode}');
        
        // If user is not authenticated, redirect to login
        if (currentUser == null) {
          return const LoginScreen();
        }
        
        return _buildMainContent(context, darkModeProvider);
      },
    );
  }

  Widget _buildMainContent(BuildContext context, DarkModeProvider darkModeProvider) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: widget.isCurrentUser ? NavDrawer(
        userEmail: FirebaseAuth.instance.currentUser?.email,
        userName: FirebaseAuth.instance.currentUser?.displayName,
        userPhotoUrl: FirebaseAuth.instance.currentUser?.photoURL,
      ) : null,
      body: Container(
        decoration: darkModeProvider.isDarkMode 
            ? const BoxDecoration(
                color: AppColors.darkBackground,
              )
            : const BoxDecoration(
                gradient: AppColors.mainGradient,
              ),
        child: Stack(
          children: [
            SafeArea(
              child: ResponsiveUtils.isWideScreen(context) 
                  ? _buildDesktopLayout(context)
                  : _buildMobileLayout(context),
            ),
            if (_showSearchResults) _buildSearchOverlay(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(darkModeProvider),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1400),
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      child: _buildMobileLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHealthScoreSection(),
                const SizedBox(height: 32.0),
                _buildFollowingSection(),
                const SizedBox(height: 32.0),
                _buildFollowingContentSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Show back button for other user profiles, menu for current user
              if (widget.isCurrentUser) ...[
                IconButton(
                  icon: const Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Image.asset(
                  'assets/img/reptiGramLogo.png',
                  fit: BoxFit.contain,
                  width: 30,
                  height: 30,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.pets,
                      color: Colors.white,
                      size: 20,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.isCurrentUser ? 'Reptigram' : _getProfileDisplayName(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Only show search for current user
              if (widget.isCurrentUser) ...[
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 24),
                  onPressed: () {
                    setState(() {
                      _showSearchResults = !_showSearchResults;
                      if (!_showSearchResults) {
                        _searchController.clear();
                        _searchResults = [];
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                  onPressed: () {
                    // Handle notifications
                  },
                ),
              ] else ...[
                // Show follow/unfollow button for other users
                _buildFollowButton(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getProfileDisplayName() {
    if (_profileUser == null) return 'Loading...';
    
    final displayName = _profileUser!['displayName']?.toString();
    final username = _profileUser!['username']?.toString();
    final email = _profileUser!['email']?.toString();
    
    return displayName?.isNotEmpty == true 
        ? displayName!
        : username?.isNotEmpty == true 
            ? username!
            : email?.isNotEmpty == true 
                ? email!.split('@')[0]
                : 'Unknown User';
  }

  String? _getBackgroundImageUrl() {
    if (widget.isCurrentUser) {
      return _currentUserData?['backgroundUrl'];
    } else {
      return _profileUser?['backgroundUrl'];
    }
  }

  String _getCustomPhrase() {
    if (widget.isCurrentUser) {
      return _customPhrase ?? "\"Patience is a reptile's superpower.\"";
    } else {
      return _profileUser?['customPhrase']?.toString() ?? "\"Patience is a reptile's superpower.\"";
    }
  }

  Widget _buildFollowButton() {
    if (_isLoadingFollowStatus) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[600],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isFollowing ? Colors.grey[700] : Colors.blue,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHealthScoreSection() {
    return Center(
      child: GestureDetector(
        onTap: widget.isCurrentUser ? _uploadBackgroundImage : null,
        child: Stack(
          children: [
            Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
          decoration: BoxDecoration(
            // Use custom background if available, otherwise use gradient
            image: _getBackgroundImageUrl() != null
                ? DecorationImage(
                    image: NetworkImage(_getBackgroundImageUrl()!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.3),
                      BlendMode.darken,
                    ),
                  )
                : null,
            gradient: _getBackgroundImageUrl() == null
                ? const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(16.0),
          ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User profile picture
            GestureDetector(
              onTap: widget.isCurrentUser ? _uploadProfilePicture : null,
              child: MouseRegion(
                onEnter: widget.isCurrentUser ? (_) => setState(() => _isHoveringProfilePic = true) : null,
                onExit: widget.isCurrentUser ? (_) => setState(() => _isHoveringProfilePic = false) : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _buildProfilePicture(),
                      ),
                    ),
                    // Loading indicator
                    if (widget.isCurrentUser && _isUploadingProfilePic)
                      const Positioned.fill(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    // Hover overlay for current user
                    if (widget.isCurrentUser && _isHoveringProfilePic && !_isUploadingProfilePic)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 24),
                              SizedBox(height: 4),
                              Text(
                                'Change',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: widget.isCurrentUser ? _updateCustomPhrase : null,
              child: MouseRegion(
                onEnter: widget.isCurrentUser ? (_) => setState(() => _isHoveringPhrase = true) : null,
                onExit: widget.isCurrentUser ? (_) => setState(() => _isHoveringPhrase = false) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: widget.isCurrentUser && _isHoveringPhrase ? BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ) : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _getCustomPhrase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (widget.isCurrentUser && _isHoveringPhrase) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Todo: Badge to be added here at a later date
            // const SizedBox(height: 4),
            // const Text(
            //   '92',
            //   style: TextStyle(
            //     color: Colors.white,
            //     fontSize: 24,
            //     fontWeight: FontWeight.bold,
            //   ),
            // ),
          ],
        ),
            ),
            // Background upload indicator for current user
            if (widget.isCurrentUser)
              Positioned(
                top: 8,
                right: 8,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHoveringBackground = true),
                  onExit: (_) => setState(() => _isHoveringBackground = false),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _isUploadingBackground
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            Icons.wallpaper,
                            color: Colors.white,
                            size: _isHoveringBackground ? 18 : 16,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    // For current user, use their profile picture if available
    if (widget.isCurrentUser && _currentUserData != null) {
      final photoUrl = _currentUserData!['photoUrl'] ?? _currentUserData!['photoURL'];
      
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
        return Image.network(
          photoUrl,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultProfilePicture();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[600],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        );
      }
    }
    
    // For other users, use their profile picture if available
    if (!widget.isCurrentUser && _profileUser != null) {
      final photoUrl = _profileUser!['photoUrl'] ?? _profileUser!['photoURL'];
      
      if (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
        return Image.network(
          photoUrl,
          fit: BoxFit.cover,
          width: 80,
          height: 80,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultProfilePicture();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[600],
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        );
      }
    }
    
    // Default fallback
    return _buildDefaultProfilePicture();
  }

  Widget _buildDefaultProfilePicture() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[600],
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 40,
      ),
    );
  }

  Widget _buildFollowingSection() {
    // Show different content based on user type
    if (widget.isCurrentUser) {
      return _buildCurrentUserFollowingSection();
    } else {
      return _buildOtherUserFollowingSection();
    }
  }

  Widget _buildCurrentUserFollowingSection() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    // Use real followed users from Firestore
    final followingUsers = _followedUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Following',
          style: TextStyle(
            color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            SizedBox(
              height: 80,
              child: _isLoadingFollowedUsers
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : followingUsers.isEmpty
                      ? const Center(
                          child: Text(
                            'No users followed yet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : Stack(
                children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.horizontal,
                              itemCount: (followingUsers.length / 6).ceil(), // 6 users per page
                    onPageChanged: (pageIndex) {
                      setState(() {
                        _currentFollowingPage = pageIndex;
                      });
                    },
                itemBuilder: (context, pageIndex) {
                  final startIndex = pageIndex * 6;
                  final endIndex = (startIndex + 6).clamp(0, followingUsers.length);
                  
                  // Safety check to prevent RangeError
                  if (startIndex >= followingUsers.length) {
                    return const SizedBox.shrink();
                  }
                  
                  final pageUsers = followingUsers.sublist(startIndex, endIndex);
                      
                                // Use spaceAround for even distribution, or center if less than 6 users
                      return Row(
                                  mainAxisAlignment: pageUsers.length < 6 
                                      ? MainAxisAlignment.center 
                                      : MainAxisAlignment.spaceAround,
                        children: pageUsers.map((user) {
                          return _buildFollowingUserCard(
                            user['name'] as String, 
                            user['avatar'] as String,
                            user['uid'] as String,
                          );
                        }).toList(),
                      );
                    },
                  ),
                  // Right fade indicator - only show in dark mode
                  if (darkModeProvider.isDarkMode)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
        // Page indicators
            if (followingUsers.isNotEmpty && (followingUsers.length / 6).ceil() > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              (followingUsers.length / 6).ceil(),
              (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentFollowingPage 
                        ? Colors.white 
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserAvatar(String avatarUrl, String name) {
    // Check if it's a network URL (real photo) or asset/default
    if (avatarUrl.isEmpty || !avatarUrl.startsWith('http')) {
      // No photo or asset path - show letter avatar
      return _buildLetterAvatar(name);
    }

    // Check if this image previously failed
    if (_imageErrors.containsKey(avatarUrl)) {
      return _buildLetterAvatar(name);
    }

    // Show network image with proper error handling (same as post screen)
    return CircleAvatar(
      radius: 23,
      backgroundImage: NetworkImage(avatarUrl),
      onBackgroundImageError: (exception, stackTrace) {
        // Handle image loading errors by showing letter avatar
        print('Following avatar image failed to load: $avatarUrl, error: $exception');
        if (mounted) {
          // Use post-frame callback to avoid calling setState during paint
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _imageErrors[avatarUrl] = true;
              });
            }
          });
        }
      },
      child: null, // Remove child to let background image show
    );
  }

  Widget _buildLetterAvatar(String name) {
    // Get the first letter of the name
    final initial = name[0].toUpperCase();
    
    // Generate a consistent color based on the name
    final color = _getColorFromName(name);
    
    return CircleAvatar(
      radius: 23,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
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

  Widget _buildFollowingUserCard(String name, String avatar, String userId) {
    return GestureDetector(
      onTap: () {
        // Navigate to the user's dashboard
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomeDashboardScreen(
              userId: userId,
              isCurrentUser: false,
            ),
          ),
        );
      },
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[600]!, width: 2),
              ),
              child: ClipOval(
                child: _buildUserAvatar(avatar, name),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherUserFollowingSection() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Following',
          style: TextStyle(
            color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: darkModeProvider.isDarkMode ? AppColors.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: darkModeProvider.isDarkMode ? AppColors.darkCardBorder : Colors.grey[300]!,
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFollowStatsItem('Following', _profileUser?['followingCount'] ?? 0),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[600],
                  ),
                  _buildFollowStatsItem('Followers', _profileUser?['followersCount'] ?? 0),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowStatsItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildOtherUserProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile Info',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingProfileUser)
          const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          )
        else if (_profileUser != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[700]!, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Username: ${_profileUser!['username'] ?? 'Not set'}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Email: ${_profileUser!['email'] ?? 'Not set'}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Member since: ${_profileUser!['createdAt'] ?? 'Unknown'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          )
        else
          const Center(
            child: Text(
              'User not found',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFollowingContentSection() {
    // Show different content based on user type
    if (widget.isCurrentUser) {
      return _buildTerrariumSection();
    } else {
      return _buildOtherUserTerrariumSection();
    }
  }

  Widget _buildTerrariumSection() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Terrarium',
          style: TextStyle(
            color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildUserPhotosGrid(),
      ],
    );
  }

  Widget _buildOtherUserTerrariumSection() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context, listen: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Terrarium',
          style: TextStyle(
            color: darkModeProvider.isDarkMode ? AppColors.darkText : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildUserPhotosGrid(),
      ],
    );
  }

  Widget _buildUserPhotosGrid() {
    // Show loading indicator if we're loading and have no photos yet
    if (_isLoadingUserPhotos && _userPhotos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    // Only show "No photos yet" if we're NOT loading and truly have no photos
    if (!_isLoadingUserPhotos && _userPhotos.isEmpty) {
      return const Center(
        child: Column(
          children: [
            SizedBox(height: 40),
            Icon(
              Icons.photo_library_outlined,
              color: Colors.white70,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No photos yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start building your terrarium by adding photos!',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Load more photos when scrolling near the bottom
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          if (_hasMorePhotos && !_isLoadingUserPhotos) {
            _loadUserPhotos();
          }
        }
        return false;
      },
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 1.0,
        ),
        itemCount: _userPhotos.length + (_isLoadingUserPhotos ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator for the last item if loading more
          if (index >= _userPhotos.length) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.grey[800],
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final photo = _userPhotos[index];
          return _buildPhotoCard(photo);
        },
      ),
    );
  }

  Widget _buildFollowingContentGrid() {
    final posts = [
      {'icon': Icons.video_library, 'color': Colors.orange, 'caption': "Alex - Leos Terrarium Update", 'type': 'video'},
      {'icon': Icons.photo, 'color': Colors.brown, 'caption': "Sarah - New Python Setup", 'type': 'photo'},
      {'icon': Icons.video_library, 'color': Colors.green, 'caption': "Mike - Chameleon Habitat", 'type': 'video'},
      {'icon': Icons.photo, 'color': Colors.yellow, 'caption': "Emma - Feeding Time", 'type': 'photo'},
      {'icon': Icons.video_library, 'color': Colors.teal, 'caption': "Jake - Gecko's Dinner Time", 'type': 'video'},
      {'icon': Icons.photo, 'color': Colors.purple, 'caption': "Lisa - Close-up View", 'type': 'photo'},
      {'icon': Icons.video_library, 'color': Colors.red, 'caption': "Tom - Snake Shedding", 'type': 'video'},
      {'icon': Icons.photo, 'color': Colors.blue, 'caption': "Anna - New Enclosure", 'type': 'photo'},
      {'icon': Icons.video_library, 'color': Colors.pink, 'caption': "Chris - Daily Care Routine", 'type': 'video'},
      {'icon': Icons.photo, 'color': Colors.indigo, 'caption': "Maria - Health Check", 'type': 'photo'},
      {'icon': Icons.video_library, 'color': Colors.cyan, 'caption': "David - Breeding Setup", 'type': 'video'},
      {'icon': Icons.photo, 'color': Colors.amber, 'caption': "Sophie - New Addition", 'type': 'photo'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return _buildPostCard(
          post['icon'] as IconData, 
          post['color'] as Color, 
          post['caption'] as String,
          post['type'] as String
        );
      },
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    // Use the same simple approach as feed screen - just use firebaseUrl
    final String? imageUrl = photo['firebaseUrl'] ?? photo['url'];
    
    final String title = photo['title'] ?? 'Photo';
    final int likesCount = photo['likesCount'] ?? 0;
    final bool isLiked = photo['isLiked'] ?? false;

    return GestureDetector(
      onTap: () {
        // Navigate to full-screen photo view
        _showFullScreenPhoto(photo);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          color: darkModeProvider.isDarkMode ? AppColors.darkCardBackground : Colors.white,
          border: Border.all(
            color: darkModeProvider.isDarkMode ? AppColors.darkCardBorder : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Stack(
            children: [
              // Photo or placeholder - use same simple approach as feed screen
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print('🖼️ Photo failed to load: $imageUrl, error: $error');
                    return _buildPhotoPlaceholder();
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                )
              else
                _buildPhotoPlaceholder(),
              
              // Overlay with title and likes
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                likesCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          // Show source badge (album, binder, notebook, or photos only)
                          if (photo['albumName'] != null || photo['binderName'] != null || photo['notebookName'] != null || photo['source'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getSourceColor(photo),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getSourceLabel(photo),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildPhotoPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: const Center(
        child: Icon(
          Icons.photo,
          color: Colors.white70,
          size: 32,
        ),
      ),
    );
  }

  void _showFullScreenPhoto(Map<String, dynamic> photo) {
    // Convert photo data to PhotoData model for full-screen view
    // Handle timestamp conversion from Firestore Timestamp to int
    int timestamp;
    if (photo['timestamp'] is Timestamp) {
      timestamp = (photo['timestamp'] as Timestamp).millisecondsSinceEpoch;
    } else if (photo['timestamp'] is int) {
      timestamp = photo['timestamp'] as int;
    } else {
      timestamp = DateTime.now().millisecondsSinceEpoch;
    }
    
    final photoData = PhotoData(
      id: photo['id'] ?? '',
      file: null,
      firebaseUrl: photo['firebaseUrl'] ?? photo['url'],
      title: photo['title'] ?? 'Photo',
      comment: photo['comment'] ?? '',
      isLiked: photo['isLiked'] ?? false,
      userId: photo['userId'] ?? _effectiveUserId ?? '',
      timestamp: timestamp,
      likesCount: photo['likesCount'] ?? 0,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => FullScreenPhotoView(
          photo: photoData,
          onLikeToggled: _toggleLike,
        ),
      ),
    );
  }

  Future<void> _toggleLike(PhotoData photo) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final currentUser = appState.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like photos')),
      );
      return;
    }

    try {
      // Optimistic update
      setState(() {
        photo.isLiked = !photo.isLiked;
        photo.likesCount += photo.isLiked ? 1 : -1;
      });

      // Update cached like data in photo document
      await LikeCacheService.updatePhotoLikeCache(
        photoId: photo.id,
        userId: currentUser.uid,
        isLiked: photo.isLiked,
      );

      // Update the photo in _userPhotos list
      final photoIndex = _userPhotos.indexWhere((p) => p['id'] == photo.id);
      if (photoIndex != -1) {
        setState(() {
          _userPhotos[photoIndex]['isLiked'] = photo.isLiked;
          _userPhotos[photoIndex]['likesCount'] = photo.likesCount;
        });
      }

    } catch (e) {
      // Revert on error
      setState(() {
        photo.isLiked = !photo.isLiked;
        photo.likesCount += photo.isLiked ? 1 : -1;
      });
      print('Error toggling like: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: ${e.toString()}')),
      );
    }
  }

  String _getSourceLabel(Map<String, dynamic> photo) {
    final source = photo['source'] ?? '';
    final albumName = photo['albumName'];
    final binderName = photo['binderName'];
    final notebookName = photo['notebookName'];

    if (albumName != null && albumName.isNotEmpty) {
      return albumName;
    } else if (binderName != null && binderName.isNotEmpty) {
      return binderName;
    } else if (notebookName != null && notebookName.isNotEmpty && notebookName != 'Unsorted') {
      return notebookName;
    } else if (source == 'photosOnly') {
      return 'Photos Only';
    } else if (source == 'binders') {
      return 'Binder';
    } else if (source == 'albums') {
      return 'Album';
    } else {
      return 'Photo';
    }
  }

  Color _getSourceColor(Map<String, dynamic> photo) {
    final source = photo['source'] ?? '';
    final albumName = photo['albumName'];
    final binderName = photo['binderName'];
    final notebookName = photo['notebookName'];

    if (albumName != null && albumName.isNotEmpty) {
      return Colors.blue.withOpacity(0.8);
    } else if (binderName != null && binderName.isNotEmpty) {
      return Colors.green.withOpacity(0.8);
    } else if (notebookName != null && notebookName.isNotEmpty && notebookName != 'Unsorted') {
      return Colors.purple.withOpacity(0.8);
    } else if (source == 'photosOnly') {
      return Colors.orange.withOpacity(0.8);
    } else if (source == 'binders') {
      return Colors.green.withOpacity(0.8);
    } else if (source == 'albums') {
      return Colors.blue.withOpacity(0.8);
    } else {
      return Colors.grey.withOpacity(0.8);
    }
  }

  Widget _buildPostCard(IconData icon, Color color, String caption, String type) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: Colors.grey[800],
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
                    color: color.withOpacity(0.8),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                // Photo/Video indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type == 'video' ? Icons.play_arrow : Icons.photo,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              caption,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    return Container(
      color: darkModeProvider.isDarkMode 
          ? AppColors.darkBackground.withOpacity(0.95)
          : Colors.black.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            // Search header
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () {
                      setState(() {
                        _showSearchResults = false;
                        _searchController.clear();
                        _searchResults = [];
                        _displayedResultsCount = 20;
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: 'Search users by name, username, or email...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                ],
              ),
            ),
            // Search results with infinite scroll
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _searchResults.isEmpty && _searchController.text.isNotEmpty
                      ? const Center(
                          child: Text(
                            'No users found',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollInfo) {
                            // Check if we've scrolled to near the bottom (within 200 pixels)
                            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                              // Load more results if there are more available
                              if (_displayedResultsCount < _searchResults.length) {
                                _loadMoreResults();
                              }
                            }
                            return false;
                          },
                          child: ListView.builder(
                            itemCount: _displayedResultsCount,
                            itemBuilder: (context, index) {
                              // Safety check to prevent RangeError
                              if (index >= _searchResults.length) {
                                return const SizedBox.shrink();
                              }
                              
                              final user = _searchResults[index];
                              return _buildSearchResultItem(user);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildSearchResultItem(Map<String, dynamic> user) {
    final darkModeProvider = Provider.of<DarkModeProvider>(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: darkModeProvider.isDarkMode ? AppColors.darkCardBackground : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: darkModeProvider.isDarkMode ? AppColors.darkCardBorder : Colors.grey[300]!,
          width: 0.5,
        ),
      ),
      child: ListTile(
        leading: _buildSearchAvatar(user['photoURL'], user['displayName']),
        title: Text(
          user['displayName'],
          style: TextStyle(
            color: darkModeProvider.isDarkMode ? AppColors.darkText : AppColors.titleText,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user['username']}',
              style: TextStyle(
                color: darkModeProvider.isDarkMode ? AppColors.darkTextSecondary : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              user['email'],
              style: TextStyle(
                color: darkModeProvider.isDarkMode ? AppColors.darkTextSecondary : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.person_add,
            color: darkModeProvider.isDarkMode ? AppColors.darkText : AppColors.titleText,
            size: 20,
          ),
          onPressed: () {
            // Handle follow user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Followed ${user['displayName']}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        onTap: () {
          // Navigate to user profile using dynamic dashboard pattern
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeDashboardScreen(
                userId: user['uid'],
                isCurrentUser: false,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(DarkModeProvider darkModeProvider) {
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
        currentIndex: _selectedBottomNavIndex,
        onTap: (index) {
          setState(() {
            _selectedBottomNavIndex = index;
          });
          
          // Handle navigation based on selected index
          switch (index) {
            case 0:
              // Home - navigate to current user's dashboard
              if (!widget.isCurrentUser) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeDashboardScreen(isCurrentUser: true),
                  ),
                );
              }
              break;
            case 1:
              // Post - navigate to PostScreen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const PostScreen(),
                ),
              );
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
}

