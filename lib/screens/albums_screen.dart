import 'package:flutter/material.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/photo_data.dart';
import '../utils/photo_utils.dart';
import '../screens/binders_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../constants/photo_sources.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import '../utils/responsive_utils.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  List<String> albums = [];
  final ImagePicker _picker = ImagePicker();
  Map<String, List<PhotoData>> albumPhotos = {};
  bool _isLoading = false;
  final Map<String, ValueNotifier<bool>> _likeNotifiers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.initializeUser();
      await _loadAlbums();
      await _loadAlbumPhotos();
    });
  }

  Future<void> _loadAlbums() async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      // Firestore: Get albums for user
      final albumsQuery = await FirestoreService.albums
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      setState(() {
        albums = [];
        for (var doc in albumsQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['name'] != null) {
            albums.add(data['name']);
          }
        }
      });
    } catch (e) {
      print('Error loading albums: $e');
    }
  }

  Future<void> _loadAlbumPhotos() async {
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

      // Firestore: Get photos uploaded directly to albums screen (no specific album assignment)
      final photosQuery = await FirestoreService.photos
          .where('userId', isEqualTo: currentUser.uid)
          .where('source', isEqualTo: PhotoSources.albums)
          .get(); // Get all photos from albums source

      albumPhotos.clear();
      for (var album in albums) {
        albumPhotos[album] = [];
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
        
        final albumName = data['albumName'] ?? 'Unsorted';
        
        // If it's an unsorted photo, add to main grid
        if (albumName == 'Unsorted') {
          if (albumPhotos.containsKey('Main Grid')) {
            albumPhotos['Main Grid']!.add(photo);
          } else {
            albumPhotos['Main Grid'] = [photo];
          }
        } 
        // If it's assigned to a specific album, add to that album
        else if (albumPhotos.containsKey(albumName)) {
          albumPhotos[albumName]!.add(photo);
        }
      }

      setState(() {});
    } catch (e) {
      print('Error loading album photos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

                    // Firestore: Create album
                    await FirestoreService.albums.add({
                      'name': newAlbumName,
                      'createdAt': FieldValue.serverTimestamp(),
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
                // Left side - Action buttons and controls
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
                                'Albums',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.titleText,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildActionButtons(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Right side - Albums and photos grid
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0),
                    child: _buildAlbumsGrid(context),
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
                const SizedBox(height: 20.0),
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
                              .child(currentUser.uid)
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

                          // Firestore: Save photo with hierarchy info
                          await FirestoreService.photos.doc(photoId).set({
                            'url': downloadUrl,
                            'timestamp': FieldValue.serverTimestamp(),
                            'albumName': 'Unsorted', // Photos go to main grid
                            'userId': currentUser.uid,
                            'source': PhotoSources.albums,
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
                // Albums and Photos Grid
                Expanded(
                  child: _buildAlbumsGrid(context),
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
              _createNewAlbum();
            },
            icon: const Icon(Icons.create_new_folder),
            label: const Text('Create Album'),
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
                final storageRef = FirebaseStorage.instance
                    .ref()
                    .child('photos')
                    .child(currentUser.uid)
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

                // Firestore: Save photo with hierarchy info
                await FirestoreService.photos.doc(photoId).set({
                  'url': downloadUrl,
                  'timestamp': FieldValue.serverTimestamp(),
                  'albumName': 'Unsorted', // Photos go to main grid
                  'userId': currentUser.uid,
                  'source': PhotoSources.albums,
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

  Widget _buildAlbumsGrid(BuildContext context) {
    return _isLoading && albumPhotos.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.isWideScreen(context) ? 4 : 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: albums.length + (albumPhotos['Main Grid']?.length ?? 0),
            itemBuilder: (context, index) {
              // First show albums
              if (index < albums.length) {
                return _buildAlbumCard(albums[index]);
              } 
              // Then show photos from main grid
              else {
                final photoIndex = index - albums.length;
                if (albumPhotos['Main Grid'] != null && 
                    photoIndex < albumPhotos['Main Grid']!.length) {
                  final photo = albumPhotos['Main Grid']![photoIndex];
                  return _buildPhotoCard(photo);
                }
                return const SizedBox();
              }
            },
          );
  }

  Widget _buildAlbumCard(String albumName) {
    final photos = albumPhotos[albumName] ?? [];
    print('🎯 Building album card for "$albumName" with ${photos.length} photos');
    if (photos.isNotEmpty) {
      print('📸 First photo URL: ${photos[0].firebaseUrl}');
    }
    
    return GestureDetector(
      onSecondaryTapDown: (details) => _showAlbumContextMenu(context, details.globalPosition, albumName),
      onLongPress: () => _showAlbumContextMenu(context, Offset(200, 200), albumName),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BindersScreen(
                parentAlbumName: albumName,
                source: PhotoSources.binders,
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
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) {
                                    return child;
                                  }
                                  return Container(
                                    color: Colors.grey[300],
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
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            color: Colors.grey[300],
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
                          _editAlbumName(albumName);
                          break;
                        case 'delete':
                          _deleteAlbumWithContents(albumName);
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

  void _showAlbumContextMenu(BuildContext context, Offset position, String albumName) {
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
          onTap: () => _editAlbumName(albumName),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Folder'),
            ],
          ),
          onTap: () => _deleteAlbumWithContents(albumName),
        ),
      ],
    );
  }

  Future<void> _editAlbumName(String currentName) async {
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

        // Find the album document
        final albumsQuery = await FirestoreService.albums
            .where('userId', isEqualTo: currentUser.uid)
            .where('name', isEqualTo: currentName)
            .get();

        if (albumsQuery.docs.isNotEmpty) {
          final albumDoc = albumsQuery.docs.first;
          
          // Update album name
          await FirestoreService.updateAlbum(albumDoc.id, {'name': result});
          
          // Update all photos in this album
          final photosQuery = await FirestoreService.photos
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: currentName)
              .get();

          final batch = FirebaseFirestore.instance.batch();
          for (var doc in photosQuery.docs) {
            batch.update(doc.reference, {'albumName': result});
          }
          await batch.commit();

          // Update local state
          setState(() {
            final index = albums.indexOf(currentName);
            if (index != -1) {
              albums[index] = result;
              albumPhotos[result] = albumPhotos.remove(currentName) ?? [];
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder renamed to "$result"')),
          );
        }
      } catch (e) {
        print('Error renaming album: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename folder: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteAlbumWithContents(String albumName) async {
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
            'Are you sure you want to delete "$albumName" and all its contents? This action cannot be undone.',
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

        // Find the album document
        final albumsQuery = await FirestoreService.albums
            .where('userId', isEqualTo: currentUser.uid)
            .where('name', isEqualTo: albumName)
            .get();

        if (albumsQuery.docs.isNotEmpty) {
          final albumDoc = albumsQuery.docs.first;
          
          // Get all photos in this album
          final photosQuery = await FirestoreService.photos
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: albumName)
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

          // Delete binders in this album
          final bindersQuery = await FirestoreService.binders
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: albumName)
              .get();

          for (var binderDoc in bindersQuery.docs) {
            final binderData = binderDoc.data() as Map<String, dynamic>;
            final binderName = binderData['name'] as String?;
            
            if (binderName != null) {
              // Delete notebooks in this binder
              final notebooksQuery = await FirestoreService.notebooks
                  .where('userId', isEqualTo: currentUser.uid)
                  .where('albumName', isEqualTo: albumName)
                  .where('binderName', isEqualTo: binderName)
                  .get();

              for (var notebookDoc in notebooksQuery.docs) {
                batch.delete(notebookDoc.reference);
              }
            }
            
            batch.delete(binderDoc.reference);
          }

          // Delete the album document
          batch.delete(albumDoc.reference);
          
          // Commit all deletions
          await batch.commit();

          // Update local state
          setState(() {
            albums.remove(albumName);
            albumPhotos.remove(albumName);
          });

          Navigator.pop(context); // Hide loading indicator
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder "$albumName" and all contents deleted')),
          );
        }
      } catch (e) {
        Navigator.pop(context); // Hide loading indicator
        print('Error deleting album: $e');
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
          // Remove photo from all album collections
          for (var albumName in albumPhotos.keys) {
            albumPhotos[albumName]?.removeWhere((p) => p.id == photo.id);
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
                        case 'delete':
                          _deletePhoto(photo);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
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

  Future<Uint8List?> _loadImageBytes(String imageUrl) async {
    try {
      print('🔄 Loading image bytes from: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        print('✅ Image bytes loaded successfully: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        print('❌ Failed to load image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error loading image bytes: $e');
      return null;
    }
  }

  Widget _buildFallbackImage(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
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

  Future<void> _toggleLike(PhotoData photo) async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      final userId = currentUser.uid;
      final isLiked = photo.isLiked;

      if (!isLiked) {
        // Add like
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