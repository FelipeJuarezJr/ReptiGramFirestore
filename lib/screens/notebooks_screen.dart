import 'package:flutter/material.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import '../screens/binders_screen.dart';
import '../screens/photos_only_screen.dart';

import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/photo_data.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../constants/photo_sources.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import '../utils/responsive_utils.dart';
import '../widgets/move_photo_dialog.dart';

class NotebooksScreen extends StatefulWidget {
  final String notebookName;
  final String? parentBinderName;
  final String? parentAlbumName;
  final String source;
  const NotebooksScreen({
    super.key, 
    required this.notebookName,
    this.parentBinderName,
    this.parentAlbumName,
    this.source = PhotoSources.notebooks,
  });

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  List<String> notebooks = [];
  final ImagePicker _picker = ImagePicker();
  Map<String, List<PhotoData>> notebookPhotos = {};
  bool _isLoading = false;
  final Map<String, ValueNotifier<bool>> _likeNotifiers = {};
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() async {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.initializeUser();
      await _loadNotebooks();
      await _loadNotebookPhotos();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreNotebooks();
    }
  }



  Future<void> _loadNotebooks() async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;
      
      // Reset pagination state
      _lastDocument = null;
      _hasMoreData = true;

      // Load first page of notebooks
      final loadedNotebooks = await _loadNotebooksPage(currentUser, resetPagination: true);

      setState(() {
        notebooks = loadedNotebooks;
      });
      
      print('📚 Loaded ${notebooks.length} notebooks for user ${currentUser.uid}');
      print('📚 Notebooks: $notebooks');
    } catch (e) {
      print('Error loading notebooks: $e');
    }
  }

  Future<void> _loadMoreNotebooks() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      final newNotebooks = await _loadNotebooksPage(currentUser, resetPagination: false);
      
      if (newNotebooks.isNotEmpty) {
        setState(() {
          notebooks.addAll(newNotebooks);
        });
        print('✅ Loaded ${newNotebooks.length} more notebooks');
      }
    } catch (e) {
      print('❌ Error loading more notebooks: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<List<String>> _loadNotebooksPage(dynamic currentUser, {required bool resetPagination}) async {
    const int pageSize = 20;
    
    if (resetPagination) {
      _lastDocument = null;
      _hasMoreData = true;
    }

    if (!_hasMoreData) return [];

    try {
      // Get notebooks with pagination - use simple query without orderBy to avoid index requirement
      Query query = FirestoreService.notebooks
          .where('userId', isEqualTo: currentUser.uid)
          .where('binderName', isEqualTo: widget.parentBinderName)
          .where('albumName', isEqualTo: widget.parentAlbumName)
          .limit(pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final notebooksQuery = await query.get();
      
      if (notebooksQuery.docs.isEmpty) {
        _hasMoreData = false;
        return [];
      }

      _lastDocument = notebooksQuery.docs.last;
      _hasMoreData = notebooksQuery.docs.length == pageSize;

      final List<String> pageNotebooks = [];
      for (var doc in notebooksQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['name'] != null) {
          pageNotebooks.add(data['name']);
        }
      }

      // Sort locally to avoid Firestore index requirement
      pageNotebooks.sort();

      return pageNotebooks;
    } catch (e) {
      print('Error loading notebooks page: $e');
      return [];
    }
  }

  Future<void> _loadNotebookPhotos() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      // Get all likes from Firestore
      final likesQuery = await FirestoreService.likes.get();
      final likesMap = <String, Map<String, bool>>{};
      for (var doc in likesQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final photoId = data['photoId'] as String?;
        final userId = data['userId'] as String?;
        if (photoId != null && userId != null) {
          likesMap[photoId] ??= {};
          likesMap[photoId]![userId] = true;
        }
      }

      // Firestore: Get photos uploaded directly to notebooks screen (no specific notebook assignment)
      final photosQuery = await FirestoreService.photos
          .where('userId', isEqualTo: currentUser.uid)
          .where('albumName', isEqualTo: widget.parentAlbumName)
          .where('binderName', isEqualTo: widget.parentBinderName)
          .get(); // Get all photos for this binder

      print('📚 Found ${photosQuery.docs.length} photos for notebook previews');
      
      notebookPhotos.clear();
      for (var notebook in notebooks) {
        notebookPhotos[notebook] = [];
      }

      for (var doc in photosQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final photoLikes = likesMap[doc.id] ?? {};
        final isLiked = currentUser != null && photoLikes[currentUser.uid] == true;
        
        final photo = PhotoData(
          id: doc.id,
          file: null,
          firebaseUrl: data['url'],
          title: data['title'] ?? 'Photo Details',
          comment: data['comment'] ?? '',
          userId: currentUser.uid,
          isLiked: isLiked,
          likesCount: photoLikes.length,
        );
        
        // Create a ValueNotifier for this photo's like status
        _likeNotifiers[photo.id] = ValueNotifier<bool>(isLiked);
        
        final notebookName = data['notebookName'] ?? 'Unsorted';
        print('📸 Photo ${doc.id} assigned to notebook: "$notebookName"');
        
        // If it's an unsorted photo, add to main grid
        if (notebookName == 'Unsorted') {
          if (notebookPhotos.containsKey('Main Grid')) {
            notebookPhotos['Main Grid']!.add(photo);
          } else {
            notebookPhotos['Main Grid'] = [photo];
          }
        } 
        // If it's assigned to a specific notebook, add to that notebook (dynamically create entry if needed)
        else {
          if (!notebookPhotos.containsKey(notebookName)) {
            notebookPhotos[notebookName] = [];
            print('📚 Created new notebook entry for: "$notebookName"');
          }
          notebookPhotos[notebookName]!.add(photo);
        }
      }

      print('📚 Final notebookPhotos map: ${notebookPhotos.keys.toList()}');
      for (var entry in notebookPhotos.entries) {
        print('📚 "${entry.key}": ${entry.value.length} photos');
      }

      setState(() {});
    } catch (e) {
      print('Error loading notebook photos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
        child: SafeArea(
          child: ResponsiveUtils.isWideScreen(context) 
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      children: [
        const TitleHeader(),
        const Header(initialIndex: 1),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Back button and action buttons
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
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      color: AppColors.titleText,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  const Text(
                                    'Notebooks',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.titleText,
                                    ),
                                  ),
                                ],
                              ),
                              // Display notebook name if available
                              if (widget.notebookName.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  widget.notebookName,
                                  style: const TextStyle(
                                    color: AppColors.titleText,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _buildActionButtons(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Right side - Notebooks grid
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0),
                    child: _buildNotebooksGrid(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        const TitleHeader(),
        const Header(initialIndex: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Back button row
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.titleText,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20.0),
                // Action Buttons at the top
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      'Create Notebook',
                      Icons.create_new_folder,
                      () {
                        _createNewNotebook();
                      },
                    ),
                    _buildActionButton(
                      'Add Image',
                      Icons.add_photo_alternate,
                      () async {
                        final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please log in to upload photos')),
                          );
                          return;
                        }

                        try {
                          final XFile? pickedFile = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );

                          if (pickedFile == null) return;

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          );

                          final String photoId = DateTime.now().millisecondsSinceEpoch.toString();
                          print('🔄 Starting upload for photo ID: $photoId');
                          print('👤 User ID: ${currentUser.uid}');
                          print('📁 Source: ${widget.source}');
                          
                          final storageRef = FirebaseStorage.instance
                              .ref()
                              .child('photos')
                              .child(currentUser.uid)
                              .child(photoId);
                          
                          print('📂 Storage path: photos/${currentUser.uid}/$photoId');

                          if (kIsWeb) {
                            final bytes = await pickedFile.readAsBytes();
                            print('📤 Uploading ${bytes.length} bytes to Storage...');
                            await storageRef.putData(
                              bytes,
                              SettableMetadata(contentType: 'image/jpeg'),
                            );
                          } else {
                            print('📤 Uploading file to Storage...');
                            await storageRef.putFile(
                              File(pickedFile.path),
                              SettableMetadata(contentType: 'image/jpeg'),
                            );
                          }

                          final downloadUrl = await storageRef.getDownloadURL();
                          print('✅ Storage upload complete. URL: $downloadUrl');

                          // Firestore: Save photo with hierarchy info
                          await FirestoreService.photos.doc(photoId).set({
                            'url': downloadUrl,
                            'timestamp': FieldValue.serverTimestamp(),
                            'albumName': widget.parentAlbumName,
                            'binderName': widget.parentBinderName, // Assign to current binder for preview
                            'notebookName': 'Unsorted',  // Photos go to main grid
                            'userId': currentUser.uid,
                            'source': PhotoSources.albums,  // Photos from notebooks screen
                          });

                          Navigator.pop(context); // Hide loading indicator
                          await _loadNotebookPhotos(); // Reload photos

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Photo uploaded successfully!')),
                          );
                        } catch (e) {
                          print('Error uploading photo: $e');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to upload photo: ${e.toString()}')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 74),
                // Display notebook name if available
                if (widget.notebookName.isNotEmpty) ...[
                  Text(
                    widget.notebookName,
                    style: const TextStyle(
                      color: AppColors.titleText,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Notebooks Grid
                Expanded(
                  child: _buildNotebooksGrid(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _createNewNotebook();
            },
            icon: const Icon(Icons.create_new_folder),
            label: const Text('Create Notebook'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.titleText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please log in to upload photos')),
                );
                return;
              }

              try {
                final XFile? pickedFile = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );

                if (pickedFile == null) return;

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                );

                final String photoId = DateTime.now().millisecondsSinceEpoch.toString();
                print('🔄 Starting upload for photo ID: $photoId');
                print('👤 User ID: ${currentUser.uid}');
                print('📁 Source: ${widget.source}');
                
                final storageRef = FirebaseStorage.instance
                    .ref()
                    .child('photos')
                    .child(currentUser.uid)
                    .child(photoId);
                
                print('📂 Storage path: photos/${currentUser.uid}/$photoId');

                if (kIsWeb) {
                  final bytes = await pickedFile.readAsBytes();
                  print('📤 Uploading ${bytes.length} bytes to Storage...');
                  await storageRef.putData(
                    bytes,
                    SettableMetadata(contentType: 'image/jpeg'),
                  );
                } else {
                  print('📤 Uploading file to Storage...');
                  await storageRef.putFile(
                    File(pickedFile.path),
                    SettableMetadata(contentType: 'image/jpeg'),
                  );
                }

                final downloadUrl = await storageRef.getDownloadURL();
                print('✅ Storage upload complete. URL: $downloadUrl');

                // Firestore: Save photo with hierarchy info
                await FirestoreService.photos.doc(photoId).set({
                  'url': downloadUrl,
                  'timestamp': FieldValue.serverTimestamp(),
                  'albumName': widget.parentAlbumName,
                  'binderName': widget.parentBinderName, // Assign to current binder for preview
                  'notebookName': 'Unsorted',  // Photos go to main grid
                  'userId': currentUser.uid,
                  'source': PhotoSources.albums,  // Photos from notebooks screen
                });

                Navigator.pop(context); // Hide loading indicator
                await _loadNotebookPhotos(); // Reload photos

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Photo uploaded successfully!')),
                );
              } catch (e) {
                print('Error uploading photo: $e');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to upload photo: ${e.toString()}')),
                );
              }
            },
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.titleText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotebooksGrid(BuildContext context) {
    return _isLoading && notebookPhotos.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : GridView.builder(
            controller: _scrollController,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.isWideScreen(context) ? 4 : 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: notebooks.length + (notebookPhotos['Main Grid']?.length ?? 0) + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator at the end
              if (index == notebooks.length + (notebookPhotos['Main Grid']?.length ?? 0)) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              // First show notebooks
              if (index < notebooks.length) {
                return _buildNotebookCard(notebooks[index]);
              } 
              // Then show photos from main grid
              else {
                final photoIndex = index - notebooks.length;
                if (notebookPhotos['Main Grid'] != null && 
                    photoIndex < notebookPhotos['Main Grid']!.length) {
                  final photo = notebookPhotos['Main Grid']![photoIndex];
                  return _buildPhotoCard(photo);
                }
                return const SizedBox();
              }
            },
          );
  }



  void _createNewNotebook() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newNotebookName = '';
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: const Text(
            'Create New Notebook',
            style: TextStyle(color: AppColors.titleText),
          ),
          content: TextField(
            style: const TextStyle(color: AppColors.titleText),
            decoration: const InputDecoration(
              hintText: 'Enter notebook name',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.brown),
              ),
            ),
            onChanged: (value) {
              newNotebookName = value;
            },
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown,
              ),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async {
                if (newNotebookName.isNotEmpty) {
                  try {
                    final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please log in to create notebooks')),
                      );
                      return;
                    }
                    // Firestore: create notebook (using notebooks collection)
                    await FirestoreService.notebooks.add({
                      'name': newNotebookName,
                      'createdAt': FieldValue.serverTimestamp(),
                      'userId': currentUser.uid,
                      'binderName': widget.parentBinderName,
                      'albumName': widget.parentAlbumName,
                    });
                    
                    // Update local state
                    setState(() {
                      notebooks.add(newNotebookName);
                    });

                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notebook created successfully!')),
                    );
                  } catch (e) {
                    print('Error creating notebook: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create notebook: ${e.toString()}')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotebookCard(String notebookName) {
    final photos = notebookPhotos[notebookName] ?? [];
    print('🎯 Building notebook card for "$notebookName" with ${photos.length} photos');
    if (photos.isNotEmpty) {
      print('📸 First photo URL: ${photos[0].firebaseUrl}');
    }
    
    return GestureDetector(
      onSecondaryTapDown: (details) => _showNotebookContextMenu(context, details.globalPosition, notebookName),
      onLongPress: () => _showNotebookContextMenu(context, Offset(200, 200), notebookName),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhotosOnlyScreen(
                notebookName: notebookName,
                parentBinderName: widget.parentBinderName!,
                parentAlbumName: widget.parentAlbumName!,
                source: PhotoSources.photosOnly,
              ),
            ),
          );
          
          // Refresh data when returning from PhotosOnlyScreen
          await _loadNotebooks();
          await _loadNotebookPhotos();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.inputGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (photos.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          if (photos.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: Image.network(
                                photos[0].firebaseUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                          if (photos.length > 1)
                            Expanded(
                              flex: 1,
                              child: Row(
                                children: [
                                  for (var i = 1; i < photos.length && i < 4; i++)
                                    Expanded(
                                      child: Image.network(
                                        photos[i].firebaseUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.broken_image, color: Colors.grey),
                                          );
                                        },
                                      ),
                                    ),
                                  for (var i = photos.length; i < 4; i++)
                                    Expanded(
                                      child: Container(
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    notebookName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Context menu button for accessibility
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _editNotebookName(notebookName);
                          break;
                        case 'delete':
                          _deleteNotebookWithContents(notebookName);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Edit Folder Name'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Folder'),
                          ],
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
    );
  }



  Widget _buildActionButton(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.loginGradient,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.buttonText,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.buttonText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCard(PhotoData photo) {
    print('🎨 Building photo card for: ${photo.title}');
    print('🔗 Photo URL: ${photo.firebaseUrl}');
    print('🆔 Photo ID: ${photo.id}');
    
    return GestureDetector(
      onSecondaryTapDown: (details) => _showPhotoContextMenu(context, details.globalPosition, photo),
      onLongPress: () => _showPhotoContextMenu(context, Offset(200, 200), photo),
      child: InkWell(
        onTap: () => _showEnlargedImage(photo),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.inputGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  photo.getImageUrl(size: 'thumbnail') ?? photo.firebaseUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return Container(
                      color: Colors.grey[300],
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ Network image error: $error');
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Image failed to load', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    photo.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () async {
                      // Toggle like immediately using ValueNotifier
                      final notifier = _likeNotifiers[photo.id];
                      if (notifier != null) {
                        notifier.value = !notifier.value;
                        photo.isLiked = notifier.value;
                      }
                      
                      // Save like to Firestore
                      await _toggleLike(photo);
                    },
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _likeNotifiers[photo.id] ?? ValueNotifier<bool>(photo.isLiked),
                      builder: (context, isLiked, child) {
                        return Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white,
                          size: 20,
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Context menu button for accessibility
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                    onSelected: (value) {
                      switch (value) {
                        case 'move':
                          _movePhoto(photo);
                          break;
                        case 'delete':
                          _deletePhoto(photo);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'move',
                        child: Row(
                          children: [
                            Icon(Icons.move_to_inbox, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Move Photo'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete Photo'),
                          ],
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
    );
  }


  void _showEnlargedImage(PhotoData photo) {
    if (photo.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid photo ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String photoTitle = photo.title;
    String comment = photo.comment;
    bool isLiked = _likeNotifiers[photo.id]?.value ?? photo.isLiked;
    bool hasUnsavedChanges = false;
    String originalTitle = photoTitle;
    String originalComment = comment;
    bool originalIsLiked = isLiked;
    
    final TextEditingController commentController = TextEditingController(text: comment);
    commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: comment.length)
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with editable title and close button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    String newTitle = photoTitle;
                                    return AlertDialog(
                                      backgroundColor: AppColors.dialogBackground,
                                      title: const Text(
                                        'Edit Title',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      content: TextField(
                                        style: const TextStyle(color: Colors.black),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter new title',
                                          hintStyle: TextStyle(color: Colors.grey),
                                        ),
                                        onChanged: (value) {
                                          newTitle = value;
                                        },
                                        controller: TextEditingController(text: photoTitle),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: const Text('Cancel'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text('Save'),
                                          onPressed: () {
                                            setState(() {
                                              photoTitle = newTitle;
                                              hasUnsavedChanges = photoTitle != originalTitle || comment != originalComment;
                                            });
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Row(
                                children: [
                                  Text(
                                    photoTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 30,
                            ),
                            onPressed: () {
                              if (hasUnsavedChanges) {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: AppColors.dialogBackground,
                                      title: const Text(
                                        'Unsaved Changes',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      content: const Text(
                                        'Do you want to save your changes?',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      actions: [
                                        TextButton(
                                          child: const Text('Discard'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text('Save'),
                                          onPressed: () async {
                                            photo.title = photoTitle;
                                            photo.isLiked = isLiked;
                                            photo.comment = comment;
                                            
                                            await _savePhotoChanges(photo);
                                            
                                            setState(() {
                                              originalTitle = photoTitle;
                                              originalComment = comment;
                                              originalIsLiked = isLiked;
                                              hasUnsavedChanges = false;
                                            });
                                            
                                            this.setState(() {});
                                            
                                            Navigator.of(context).pop();
                                            Navigator.of(context).pop();
                                            
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Changes saved successfully!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    // Image
                    Flexible(
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.network(
                          photo.firebaseUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return child; // Show the image immediately, no loading state
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ Enlarged network image error: $error');
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Image failed to load', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Comment section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: commentController,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.left,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 12.0,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              comment = value;
                              hasUnsavedChanges = photoTitle != originalTitle || comment != originalComment;
                            });
                          },
                        ),
                      ),
                    ),
                    // Footer with timestamp, like button, and save button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateTime.now().toString().split('.')[0],
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable: _likeNotifiers[photo.id] ?? ValueNotifier<bool>(isLiked),
                                builder: (context, currentIsLiked, child) {
                                  return IconButton(
                                    icon: Icon(
                                      currentIsLiked ? Icons.favorite : Icons.favorite_border,
                                      color: currentIsLiked ? Colors.red : Colors.white,
                                      size: 28,
                                    ),
                                    onPressed: () async {
                                      // Toggle like immediately using ValueNotifier
                                      final notifier = _likeNotifiers[photo.id];
                                      if (notifier != null) {
                                        notifier.value = !notifier.value;
                                        photo.isLiked = notifier.value;
                                        isLiked = notifier.value; // Update local state too
                                      }
                                      
                                      // Save like to Firestore immediately
                                      await _toggleLike(photo);
                                      
                                      // Update hasUnsavedChanges for other fields
                                      hasUnsavedChanges = photoTitle != originalTitle || 
                                                        comment != originalComment;
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          if (hasUnsavedChanges)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () async {
                                photo.title = photoTitle;
                                photo.isLiked = isLiked;
                                photo.comment = comment;
                                
                                await _savePhotoChanges(photo);
                                
                                setState(() {
                                  originalTitle = photoTitle;
                                  originalComment = comment;
                                  originalIsLiked = isLiked;
                                  hasUnsavedChanges = false;
                                });
                                
                                this.setState(() {});
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Changes saved successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: const Text('Save Changes'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildEnlargedFallbackImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: Colors.grey[300],
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Network image error: $error');
        print('🔗 Failed URL: $url');
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.grey),
                SizedBox(height: 8),
                Text('Image failed to load', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleLike(PhotoData photo) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like photos')),
        );
        return;
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
      print('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _savePhotoChanges(PhotoData photo) async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      if (photo.id.isEmpty) {
        throw Exception('Photo ID cannot be empty');
      }

      final updates = {
        'title': photo.title.trim(),
        'comment': photo.comment.trim(),
        'isLiked': photo.isLiked,
        'lastModified': FieldValue.serverTimestamp(),
      };

      await FirestoreService.photos.doc(photo.id).update(updates);

      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.updatePhoto(photo);
      }

    } catch (e) {
      print('Error saving photo changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  void _showNotebookContextMenu(BuildContext context, Offset position, String notebookName) {
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & MediaQuery.of(context).size,
      ),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit Folder Name'),
            ],
          ),
          onTap: () => _editNotebookName(notebookName),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Folder'),
            ],
          ),
          onTap: () => _deleteNotebookWithContents(notebookName),
        ),
      ],
    );
  }

  Future<void> _editNotebookName(String currentName) async {
    final TextEditingController controller = TextEditingController(text: currentName);
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: const Text(
            'Edit Folder Name',
            style: TextStyle(color: AppColors.titleText),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.titleText),
            decoration: const InputDecoration(
              hintText: 'Enter new folder name',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.brown),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown,
              ),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown,
              ),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != currentName) {
      try {
        final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
        if (currentUser == null) return;

        // Find the notebook document
        final notebooksQuery = await FirestoreService.notebooks
            .where('userId', isEqualTo: currentUser.uid)
            .where('albumName', isEqualTo: widget.parentAlbumName)
            .where('binderName', isEqualTo: widget.parentBinderName)
            .where('name', isEqualTo: currentName)
            .get();

        if (notebooksQuery.docs.isNotEmpty) {
          final notebookDoc = notebooksQuery.docs.first;
          
          // Update notebook name
          await FirestoreService.updateNotebook(notebookDoc.id, {'name': result});
          
          // Update all photos in this notebook
          final photosQuery = await FirestoreService.photos
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: widget.parentAlbumName)
              .where('binderName', isEqualTo: widget.parentBinderName)
              .where('notebookName', isEqualTo: currentName)
              .get();

          final batch = FirebaseFirestore.instance.batch();
          for (var doc in photosQuery.docs) {
            batch.update(doc.reference, {'notebookName': result});
          }
          await batch.commit();

          // Update local state
          setState(() {
            final index = notebooks.indexOf(currentName);
            if (index != -1) {
              notebooks[index] = result;
              notebookPhotos[result] = notebookPhotos.remove(currentName) ?? [];
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder renamed to "$result"')),
          );
        }
      } catch (e) {
        print('Error renaming notebook: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename folder: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteNotebookWithContents(String notebookName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: const Text(
            'Delete Folder',
            style: TextStyle(color: AppColors.titleText),
          ),
          content: Text(
            'Are you sure you want to delete "$notebookName" and all its contents? This action cannot be undone.',
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
        final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
        if (currentUser == null) return;

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

        // Find the notebook document
        final notebooksQuery = await FirestoreService.notebooks
            .where('userId', isEqualTo: currentUser.uid)
            .where('albumName', isEqualTo: widget.parentAlbumName)
            .where('binderName', isEqualTo: widget.parentBinderName)
            .where('name', isEqualTo: notebookName)
            .get();

        if (notebooksQuery.docs.isNotEmpty) {
          final notebookDoc = notebooksQuery.docs.first;
          
          // Get all photos in this notebook
          final photosQuery = await FirestoreService.photos
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: widget.parentAlbumName)
              .where('binderName', isEqualTo: widget.parentBinderName)
              .where('notebookName', isEqualTo: notebookName)
              .get();

          // Delete photos from storage and Firestore
          final batch = FirebaseFirestore.instance.batch();
          final storage = FirebaseStorage.instance;
          
          for (var doc in photosQuery.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final photoUrl = data['url'] as String?;
            
            // Delete from storage if URL exists
            if (photoUrl != null) {
              try {
                final ref = storage.refFromURL(photoUrl);
                await ref.delete();
              } catch (e) {
                print('Error deleting photo from storage: $e');
              }
            }
            
            // Delete likes for this photo
            final likesQuery = await FirestoreService.likes
                .where('photoId', isEqualTo: doc.id)
                .get();
            for (var likeDoc in likesQuery.docs) {
              batch.delete(likeDoc.reference);
            }
            
            // Delete comments for this photo
            final commentsQuery = await FirestoreService.comments
                .where('photoId', isEqualTo: doc.id)
                .get();
            for (var commentDoc in commentsQuery.docs) {
              batch.delete(commentDoc.reference);
            }
            
            // Delete the photo document
            batch.delete(doc.reference);
          }

          // Delete the notebook document
          batch.delete(notebookDoc.reference);
          
          // Commit all deletions
          await batch.commit();

          // Update local state
          setState(() {
            notebooks.remove(notebookName);
            notebookPhotos.remove(notebookName);
          });

          Navigator.pop(context); // Hide loading indicator
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder "$notebookName" and all contents deleted')),
          );
        }
      } catch (e) {
        Navigator.pop(context); // Hide loading indicator
        print('Error deleting notebook: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete folder: ${e.toString()}')),
        );
      }
    }
  }

  void _showPhotoContextMenu(BuildContext context, Offset position, PhotoData photo) {
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & MediaQuery.of(context).size,
      ),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.move_to_inbox, color: Colors.blue),
              SizedBox(width: 8),
              Text('Move Photo'),
            ],
          ),
          onTap: () => _movePhoto(photo),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Photo'),
            ],
          ),
          onTap: () => _deletePhoto(photo),
        ),
      ],
    );
  }

  Future<void> _deletePhoto(PhotoData photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: const Text(
            'Delete Photo',
            style: TextStyle(color: AppColors.titleText),
          ),
          content: Text(
            'Are you sure you want to delete this photo? This action cannot be undone.',
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
        final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
        if (currentUser == null) return;

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

        // Delete from storage
        if (photo.firebaseUrl != null) {
          try {
            final storage = FirebaseStorage.instance;
            final ref = storage.refFromURL(photo.firebaseUrl!);
            await ref.delete();
          } catch (e) {
            print('Error deleting photo from storage: $e');
          }
        }

        // Delete likes for this photo
        final likesQuery = await FirestoreService.likes
            .where('photoId', isEqualTo: photo.id)
            .get();

        // Delete comments for this photo
        final commentsQuery = await FirestoreService.comments
            .where('photoId', isEqualTo: photo.id)
            .get();

        // Delete photo document and related data
        final batch = FirebaseFirestore.instance.batch();
        
        for (var likeDoc in likesQuery.docs) {
          batch.delete(likeDoc.reference);
        }
        
        for (var commentDoc in commentsQuery.docs) {
          batch.delete(commentDoc.reference);
        }
        
        batch.delete(FirestoreService.photos.doc(photo.id));
        
        await batch.commit();

        // Update local state
        setState(() {
          // Remove photo from all notebook collections
          for (var notebookName in notebookPhotos.keys) {
            notebookPhotos[notebookName]?.removeWhere((p) => p.id == photo.id);
          }
          // Remove the like notifier
          _likeNotifiers.remove(photo.id);
        });

        Navigator.pop(context); // Hide loading indicator
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo deleted successfully')),
        );
      } catch (e) {
        Navigator.pop(context); // Hide loading indicator
        print('Error deleting photo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete photo: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _movePhoto(PhotoData photo) async {
    // For notebooks_screen, we need to get the current context from the widget properties
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return MovePhotoDialog(
          photo: photo,
          currentAlbumName: widget.parentAlbumName ?? 'Unsorted',
          currentBinderName: widget.parentBinderName,
          currentNotebookName: widget.notebookName,
          sourceContext: 'notebooks',
        );
      },
    );
    
    // If photo was moved successfully, refresh the data
    if (result == true) {
      await _loadNotebooks();
      await _loadNotebookPhotos();
    }
  }
} 