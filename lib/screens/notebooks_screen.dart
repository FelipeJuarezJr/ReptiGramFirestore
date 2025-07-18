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
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.initializeUser();
      await _loadNotebooks();
      await _loadNotebookPhotos();
    });
  }



  Future<void> _loadNotebooks() async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;
      
      // Firestore: get notebooks for user and binder (using notebooks collection)
      final query = await FirestoreService.notebooks
          .where('userId', isEqualTo: currentUser.uid)
          .where('binderName', isEqualTo: widget.parentBinderName)
          .where('albumName', isEqualTo: widget.parentAlbumName)
          .get();
      
      setState(() {
        notebooks = [];
        for (var doc in query.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['name'] != null) {
            notebooks.add(data['name']);
          }
        }
      });
      
      print('📚 Loaded ${notebooks.length} notebooks for user ${currentUser.uid}');
      print('📚 Notebooks: $notebooks');
    } catch (e) {
      print('Error loading notebooks: $e');
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
          child: Column(
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
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BindersScreen(
                                    binderName: widget.notebookName,
                                    parentAlbumName: widget.parentAlbumName,
                                    source: PhotoSources.binders,
                                  ),
                                ),
                              );
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
                      // Notebooks Grid below
                      Expanded(
                        child: _isLoading && notebookPhotos.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,  // 3 items per row
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.75,  // Make items slightly taller than wide
                              ),
                              itemCount: notebooks.length + (notebookPhotos['Main Grid']?.length ?? 0),  // Show both notebooks and photos
                              itemBuilder: (context, index) {
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
    
    return InkWell(
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
          ],
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
    
    return InkWell(
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
              child: FutureBuilder<Uint8List?>(
                future: _loadImageBytes(photo.firebaseUrl!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container();
                  }
                  
                  if (snapshot.hasError) {
                    print('❌ Error loading image bytes: ${snapshot.error}');
                    return _buildFallbackImage(photo.firebaseUrl!);
                  }
                  
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        print('❌ Memory image error: $error');
                        return _buildFallbackImage(photo.firebaseUrl!);
                      },
                    );
                  }
                  
                  return _buildFallbackImage(photo.firebaseUrl!);
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
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage(String url) {
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
                Text('Image failed to load', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _loadImageBytes(String url) async {
    try {
      print('🔄 Loading image bytes from: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        print('✅ Image bytes loaded successfully: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error loading image bytes: $e');
      return null;
    }
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
} 