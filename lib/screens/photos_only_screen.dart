import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../styles/colors.dart';
import '../common/header.dart';
import '../common/title_header.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/photo_data.dart';
import '../utils/photo_utils.dart';

class PhotosOnlyScreen extends StatefulWidget {
  final String notebookName;
  final String parentBinderName;
  final String parentAlbumName;

  const PhotosOnlyScreen({
    super.key,
    required this.notebookName,
    required this.parentBinderName,
    required this.parentAlbumName,
  });

  @override
  State<PhotosOnlyScreen> createState() => _PhotosOnlyScreenState();
}

class _PhotosOnlyScreenState extends State<PhotosOnlyScreen> {
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPhotos();
    });
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;  // Check if widget is still mounted
    
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setLoading(true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .child('photos')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<PhotoData> photos = [];

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
            photos.add(photo);
          }
        });

        appState.setPhotos(photos);
      }
    } catch (e) {
      if (mounted) {
        appState.setError(e.toString());
      }
    } finally {
      if (mounted) {
        appState.setLoading(false);
      }
    }
  }

  Future<void> _uploadImageToFirebase(XFile pickedFile) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('No user logged in');

      // Simplify the file name
      final String photoId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Simplify storage path
      final Reference ref = _storage
          .ref()
          .child('photos')
          .child(photoId);
      
      print('Uploading to path: photos/$photoId');

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
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
          File(pickedFile.path),
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': userId,
              'uploadedAt': DateTime.now().toString(),
            },
          ),
        );
      }

      final String downloadURL = await ref.getDownloadURL();
      
      // Create new PhotoData with the ID
      final PhotoData newPhoto = PhotoData(
        id: photoId,
        file: pickedFile,
        firebaseUrl: downloadURL,
        title: 'Photo Details',
        isLiked: false,
        comment: '',
        userId: userId,
      );

      // Save to Realtime Database with hierarchy info
      final DatabaseReference photoRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userId)
          .child('photos')
          .child(photoId);

      await photoRef.set({
        'url': downloadURL,
        'title': newPhoto.title,
        'isLiked': newPhoto.isLiked,
        'comment': newPhoto.comment,
        'timestamp': ServerValue.timestamp,
        'source': 'notebooks',
        'notebookName': widget.notebookName,
        'binderName': widget.parentBinderName,
        'albumName': widget.parentAlbumName,
      });

      // Update app state
      if (mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.addPhoto(newPhoto);
      }

    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
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

        // Upload to Firebase
        await _uploadImageToFirebase(pickedFile);
        
        // Hide loading indicator
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to pick image'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
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
                          const SizedBox(height: 20),
                          // Action Buttons with new layout
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,  // Align to right
                            children: [
                              _buildSmallActionButton(
                                'Add Image',
                                Icons.add_photo_alternate,
                                _pickImage,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.notebookName,
                            style: const TextStyle(
                              color: AppColors.titleText,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Photos Grid
                          Expanded(
                            child: appState.isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : appState.photos.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No photos yet.\nTap "Add Image" to get started!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.titleText,
                                            fontSize: 16,
                                          ),
                                        ),
                                      )
                                    : GridView.builder(
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 16,
                                          mainAxisSpacing: 16,
                                        ),
                                        itemCount: appState.photos.length,
                                        itemBuilder: (context, index) {
                                          return _buildPhotoCard(appState.photos[index]);
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
    );
  }

  Widget _buildSmallActionButton(String title, IconData icon, VoidCallback onTap) {
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
                photo.firebaseUrl!,  // Use the Firebase URL
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
                  photo.title,  // Use the stored title
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
    // Debug print
    print('Opening photo with ID: ${photo.id}');
    
    if (photo.id.isEmpty) {
      print('Error: Photo ID is empty');
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
    bool isLiked = photo.isLiked;  // Get initial like status
    bool hasUnsavedChanges = false;
    String originalTitle = photoTitle;
    String originalComment = comment;
    bool originalIsLiked = isLiked;  // Store original like status
    
    // Create a TextEditingController
    final TextEditingController commentController = TextEditingController(text: comment);
    // Set cursor to end
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
                                          onPressed: () {
                                            setState(() {
                                              originalTitle = photoTitle;
                                              originalComment = comment;
                                              hasUnsavedChanges = false;
                                              // Update the photo data
                                              photo.title = photoTitle;
                                              photo.isLiked = isLiked;
                                            });
                                            // Update the main state to reflect changes
                                            this.setState(() {});
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
                          photo.firebaseUrl!,  // Use the Firebase URL directly
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
                          controller: commentController,  // Use the controller
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
                                    // Update hasUnsavedChanges to include like status
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
                                  originalIsLiked = isLiked;  // Update original like status
                                  hasUnsavedChanges = false;
                                });
                                
                                // Update main state
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
      // Validate user ID
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      // Validate photo ID
      if (photo.id.isEmpty) {
        throw Exception('Photo ID cannot be empty');
      }

      // Debug prints
      print('Saving photo:');
      print('Photo ID: ${photo.id}');
      print('User ID: $userId');
      print('Title: ${photo.title}');
      print('Comment: ${photo.comment}');

      final DatabaseReference photoRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userId)
          .child('photos')
          .child(photo.id);

      final updates = {
        'title': photo.title.trim(),
        'comment': photo.comment.trim(),
        'isLiked': photo.isLiked,
        'lastModified': ServerValue.timestamp,
      };

      await photoRef.update(updates);

      // Update app state
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
      rethrow;  // Rethrow to handle in calling code
    }
  }
} 