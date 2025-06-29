import 'package:flutter/material.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import '../screens/binders_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/photo_data.dart';
import '../utils/photo_utils.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<String> albums = ['My Album'];
  final ImagePicker _picker = ImagePicker();
  Map<String, List<PhotoData>> albumPhotos = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.initializeUser();
      _loadAlbums();
      _loadAlbumPhotos();
    });
  }

  Future<void> _loadAlbums() async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .child('albums')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          albums = ['My Album']; // Reset to default album
          data.forEach((key, value) {
            if (value['name'] != null) {
              albums.add(value['name']);
            }
          });
        });
      }
    } catch (e) {
      print('Error loading albums: $e');
    }
  }

  Future<void> _loadAlbumPhotos() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .child('photos')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        albumPhotos.clear();
        
        // Initialize lists for each album
        for (var album in albums) {
          albumPhotos[album] = [];
        }

        // Sort photos into albums
        data.forEach((key, value) {
          if (value['source'] == 'albums') {
            final photo = PhotoData(
              id: key,
              file: null,
              firebaseUrl: value['url'],
              title: value['title'] ?? 'Photo Details',
              comment: value['comment'] ?? '',
              userId: currentUser.uid,
              isLiked: false,
              likesCount: 0,
            );
            
            final albumName = value['albumName'] ?? 'My Album';
            if (albumPhotos.containsKey(albumName)) {
              albumPhotos[albumName]!.add(photo);
            }
          }
        });

        setState(() {});
      }
    } catch (e) {
      print('Error loading album photos: $e');
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
                      const SizedBox(height: 60.0),
                      // Action Buttons at the top
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            'Create Album',
                            Icons.create_new_folder,
                            () {
                              _createNewAlbum();
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
                                final storageRef = FirebaseStorage.instance
                                    .ref()
                                    .child('photos')
                                    .child(photoId);

                                if (kIsWeb) {
                                  final bytes = await pickedFile.readAsBytes();
                                  await storageRef.putData(
                                    bytes,
                                    SettableMetadata(contentType: 'image/jpeg'),
                                  );
                                } else {
                                  await storageRef.putFile(
                                    File(pickedFile.path),
                                    SettableMetadata(contentType: 'image/jpeg'),
                                  );
                                }

                                final downloadUrl = await storageRef.getDownloadURL();

                                // Save to Realtime Database with hierarchy info
                                await FirebaseDatabase.instance
                                    .ref()
                                    .child('users')
                                    .child(currentUser.uid)
                                    .child('photos')
                                    .child(photoId)
                                    .set({
                                      'url': downloadUrl,
                                      'timestamp': ServerValue.timestamp,
                                      'albumName': 'My Album',
                                      'userId': currentUser.uid,
                                      'source': 'albums',
                                    });

                                Navigator.pop(context); // Hide loading indicator
                                await _loadAlbumPhotos(); // Reload photos

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
                      // Albums Grid below
                      Expanded(
                        child: _isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,  // 3 items per row
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.75,  // Make items slightly taller than wide
                              ),
                              itemCount: albums.length + (albumPhotos['My Album']?.length ?? 0),  // Show both albums and photos
                              itemBuilder: (context, index) {
                                // First show albums
                                if (index < albums.length) {
                                  return _buildAlbumCard(albums[index]);
                                } 
                                // Then show photos
                                else {
                                  final photoIndex = index - albums.length;
                                  final photo = albumPhotos['My Album']![photoIndex];
                                  return _buildPhotoCard(photo);
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

  void _createNewAlbum() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newAlbumName = '';
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: const Text(
            'Create New Album',
            style: TextStyle(color: AppColors.titleText),
          ),
          content: TextField(
            style: const TextStyle(color: AppColors.titleText),
            decoration: const InputDecoration(
              hintText: 'Enter album name',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.brown),
              ),
            ),
            onChanged: (value) {
              newAlbumName = value;
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
                if (newAlbumName.isNotEmpty) {
                  try {
                    final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please log in to create albums')),
                      );
                      return;
                    }

                    // Create a unique ID for the album
                    final albumId = DateTime.now().millisecondsSinceEpoch.toString();

                    // Save to Firebase
                    await FirebaseDatabase.instance
                        .ref()
                        .child('users')
                        .child(currentUser.uid)
                        .child('albums')
                        .child(albumId)
                        .set({
                          'name': newAlbumName,
                          'createdAt': ServerValue.timestamp,
                          'userId': currentUser.uid,
                        });

                    // Update local state
                    setState(() {
                      albums.add(newAlbumName);
                    });

                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Album created successfully!')),
                    );
                  } catch (e) {
                    print('Error creating album: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create album: ${e.toString()}')),
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

  Widget _buildAlbumCard(String albumName) {
    final photos = albumPhotos[albumName] ?? [];
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BindersScreen(
              binderName: 'My Binder',
              parentAlbumName: albumName,
            ),
          ),
        );
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
                        // Large image on top
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
                        // Three smaller images below
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
                                // Fill remaining space with empty containers if needed
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
            // Album name overlay
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
                  albumName,
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
              child: Image.network(
                photo.firebaseUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // Title overlay
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
            // Like icon
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  photo.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: photo.isLiked ? Colors.red : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
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
    bool isLiked = photo.isLiked;
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
                              IconButton(
                                icon: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.red : Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isLiked = !isLiked;
                                    hasUnsavedChanges = photoTitle != originalTitle || 
                                                      comment != originalComment ||
                                                      isLiked != originalIsLiked;
                                  });
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

  Future<void> _savePhotoChanges(PhotoData photo) async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      if (photo.id.isEmpty) {
        throw Exception('Photo ID cannot be empty');
      }

      final DatabaseReference photoRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .child('photos')
          .child(photo.id);

      final updates = {
        'title': photo.title.trim(),
        'comment': photo.comment.trim(),
        'isLiked': photo.isLiked,
        'lastModified': ServerValue.timestamp,
      };

      await photoRef.update(updates);

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