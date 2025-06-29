import 'package:flutter/material.dart';
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/photo_data.dart';
import '../screens/binders_screen.dart';
import '../screens/photos_only_screen.dart';

class NotebooksScreen extends StatefulWidget {
  final String notebookName;
  final String parentBinderName;
  final String parentAlbumName;

  const NotebooksScreen({
    super.key, 
    required this.notebookName,
    required this.parentBinderName,
    required this.parentAlbumName,
  });

  @override
  State<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends State<NotebooksScreen> {
  final ImagePicker _picker = ImagePicker();
  List<String> notebooks = ['My Notebook'];
  List<PhotoData> notebookPhotos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.initializeUser();
      await _loadNotebooks();
      _loadNotebookPhotos();
    });
  }

  Future<void> _loadNotebooks() async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .child('notebooks')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          notebooks = ['My Notebook']; // Reset to default notebook
          data.forEach((key, value) {
            if (value['name'] != null && 
                value['binderName'] == widget.parentBinderName &&
                value['albumName'] == widget.parentAlbumName) {
              notebooks.add(value['name']);
            }
          });
        });
      }
    } catch (e) {
      print('Error loading notebooks: $e');
    }
  }

  Future<void> _loadNotebookPhotos() async {
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
        notebookPhotos.clear();

        data.forEach((key, value) {
          if (value['source'] == 'notebooks' && 
              value['notebookName'] == widget.notebookName &&
              value['binderName'] == widget.parentBinderName &&
              value['albumName'] == widget.parentAlbumName) {
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
            notebookPhotos.add(photo);
          }
        });

        setState(() {});
      }
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
                            Icons.book,
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
                                      'notebookName': widget.notebookName,
                                      'binderName': widget.parentBinderName,
                                      'albumName': widget.parentAlbumName,
                                      'userId': currentUser.uid,
                                      'source': 'notebooks',
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
                      // Notebooks and Photos Grid
                      Expanded(
                        child: _isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: notebooks.length + notebookPhotos.length,
                              itemBuilder: (context, index) {
                                if (index < notebooks.length) {
                                  return _buildNotebookCard(notebooks[index]);
                                } else {
                                  final photoIndex = index - notebooks.length;
                                  if (photoIndex < notebookPhotos.length) {
                                    final photo = notebookPhotos[photoIndex];
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

  Widget _buildNotebookCard(String notebookName) {
    // Get photos for this specific notebook
    final photos = notebookPhotos.where((photo) => photo.title == notebookName).toList();
    
    return InkWell(
      onTap: () {
        // Navigate to the notebook's photos
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotosOnlyScreen(
              notebookName: notebookName,
              parentBinderName: widget.parentBinderName,
              parentAlbumName: widget.parentAlbumName,
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
            // Notebook name overlay
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
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 32,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
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

                    // Create a unique ID for the notebook
                    final notebookId = DateTime.now().millisecondsSinceEpoch.toString();

                    // Save to Firebase with hierarchy info
                    await FirebaseDatabase.instance
                        .ref()
                        .child('users')
                        .child(currentUser.uid)
                        .child('notebooks')
                        .child(notebookId)
                        .set({
                          'name': newNotebookName,
                          'createdAt': ServerValue.timestamp,
                          'userId': currentUser.uid,
                          'binderName': widget.parentBinderName,
                          'albumName': widget.parentAlbumName,
                        });

                    Navigator.of(context).pop();
                    
                    // Reload notebooks to show the new one
                    await _loadNotebooks();
                    
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
}
