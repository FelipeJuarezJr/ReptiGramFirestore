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
import '../screens/notebooks_screen.dart';
import '../screens/albums_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../constants/photo_sources.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:html' as html;
import '../utils/responsive_utils.dart';
import '../widgets/move_photo_dialog.dart';

class BindersScreen extends StatefulWidget {
  final String? binderName;
  final String? parentAlbumName;
  final String source;
  const BindersScreen({
    super.key, 
    this.binderName,
    this.parentAlbumName,
    this.source = PhotoSources.binders,
  });

  @override
  State<BindersScreen> createState() => _BindersScreenState();
}

class _BindersScreenState extends State<BindersScreen> {
  List<String> binders = [];
  final ImagePicker _picker = ImagePicker();
  Map<String, List<PhotoData>> binderPhotos = {};
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
      await _loadBinders();
      await _loadBinderPhotos();
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
      _loadMoreBinders();
    }
  }

  Future<void> _loadBinders() async {
    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      // Reset pagination state
      _lastDocument = null;
      _hasMoreData = true;

      // Load first page of binders
      final loadedBinders = await _loadBindersPage(currentUser, resetPagination: true);

      setState(() {
        binders = loadedBinders;
      });
    } catch (e) {
      print('Error loading binders: $e');
    }
  }

  Future<void> _loadMoreBinders() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
      if (currentUser == null) return;

      final newBinders = await _loadBindersPage(currentUser, resetPagination: false);
      
      if (newBinders.isNotEmpty) {
        setState(() {
          binders.addAll(newBinders);
        });
        print('✅ Loaded ${newBinders.length} more binders');
      }
    } catch (e) {
      print('❌ Error loading more binders: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<List<String>> _loadBindersPage(dynamic currentUser, {required bool resetPagination}) async {
    const int pageSize = 20;
    
    if (resetPagination) {
      _lastDocument = null;
      _hasMoreData = true;
    }

    if (!_hasMoreData) return [];

    try {
      // Get binders with pagination - use simple query without orderBy to avoid index requirement
      Query query = FirestoreService.binders
          .where('userId', isEqualTo: currentUser.uid)
          .where('albumName', isEqualTo: widget.parentAlbumName)
          .limit(pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final bindersQuery = await query.get();
      
      if (bindersQuery.docs.isEmpty) {
        _hasMoreData = false;
        return [];
      }

      _lastDocument = bindersQuery.docs.last;
      _hasMoreData = bindersQuery.docs.length == pageSize;

      final List<String> pageBinders = [];
      for (var doc in bindersQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['name'] != null) {
          pageBinders.add(data['name']);
        }
      }

      // Sort locally to avoid Firestore index requirement
      pageBinders.sort();

      return pageBinders;
    } catch (e) {
      print('Error loading binders page: $e');
      return [];
    }
  }

  Future<void> _loadBinderPhotos() async {
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

      // Firestore: Get photos for this album that are directly assigned to binders (not to notebooks)
      final photosQuery = await FirestoreService.photos
          .where('userId', isEqualTo: currentUser.uid)
          .where('albumName', isEqualTo: widget.parentAlbumName)
          .get(); // Get all photos for this album
          
      // Also check for photos specifically assigned to "Awesome Binder" for debugging
      final awesomeBinderQuery = await FirestoreService.photos
          .where('userId', isEqualTo: currentUser.uid)
          .where('binderName', isEqualTo: 'Awesome Binder')
          .get();
      print('🔍 Found ${awesomeBinderQuery.docs.length} photos assigned to "Awesome Binder"');
      for (var doc in awesomeBinderQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('  Awesome Binder photo: ${doc.id} - source=${data['source']}, albumName=${data['albumName']}');
      }
      
      // Check for photos assigned to "Awesome Binder" in the current album
      final awesomeBinderInAlbumQuery = await FirestoreService.photos
          .where('userId', isEqualTo: currentUser.uid)
          .where('binderName', isEqualTo: 'Awesome Binder')
          .where('albumName', isEqualTo: widget.parentAlbumName)
          .get();
      print('🔍 Found ${awesomeBinderInAlbumQuery.docs.length} photos assigned to "Awesome Binder" in album "${widget.parentAlbumName}"');

      binderPhotos.clear();
      // Initialize binders
      for (var binder in binders) {
        binderPhotos[binder] = [];
      }
      // Initialize Unsorted collection for photos without specific binder assignment
      binderPhotos['Unsorted'] = [];

      print('📸 Found ${photosQuery.docs.length} total photos for this album');
      print('🔍 All photos data:');
      for (var doc in photosQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final notebookName = data['notebookName'];
        final binderName = data['binderName'];
        print('  Photo ${doc.id}: source=${data['source']}, albumName=${data['albumName']}, binderName=$binderName, notebookName=$notebookName');
      }
      
      for (var doc in photosQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('🔍 Processing photo: ${doc.id} with data: $data');
        
        // Skip photos that are assigned to notebooks (they have a notebookName field)
        final notebookName = data['notebookName'];
        if (notebookName != null && notebookName.isNotEmpty && notebookName != 'Unsorted') {
          print('⏭️ Skipping photo ${doc.id} - assigned to notebook: $notebookName');
          continue;
        }
        
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
        
        final binderName = data['binderName'] ?? 'Unsorted';
        print('📁 Assigning photo to binder: $binderName');
        
        // If it's an unsorted photo, add to main grid
        if (binderName == 'Unsorted') {
          if (binderPhotos.containsKey('Unsorted')) {
            binderPhotos['Unsorted']!.add(photo);
            print('✅ Added photo to Unsorted collection. Total: ${binderPhotos['Unsorted']!.length}');
          } else {
            binderPhotos['Unsorted'] = [photo];
            print('✅ Created Unsorted collection with photo');
          }
        } 
        // If it's assigned to a specific binder, add to that binder (dynamically create entry if needed)
        else {
          if (!binderPhotos.containsKey(binderName)) {
            binderPhotos[binderName] = [];
            print('📁 Created new binder entry for: "$binderName"');
          }
          binderPhotos[binderName]!.add(photo);
          print('✅ Added photo to binder "$binderName". Total: ${binderPhotos[binderName]!.length}');
        }
      }

      print('📁 Final binderPhotos map: ${binderPhotos.keys.toList()}');
      for (var entry in binderPhotos.entries) {
        print('📁 "${entry.key}": ${entry.value.length} photos');
      }
      
      setState(() {});
    } catch (e) {
      print('Error loading binder photos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _createNewBinder() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String newBinderName = '';
        return AlertDialog(
          backgroundColor: AppColors.dialogBackground,
          title: const Text(
            'Create New Binder',
            style: TextStyle(color: AppColors.titleText),
          ),
          content: TextField(
            style: const TextStyle(color: AppColors.titleText),
            decoration: const InputDecoration(
              hintText: 'Enter binder name',
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.brown),
              ),
            ),
            onChanged: (value) {
              newBinderName = value;
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
                if (newBinderName.isNotEmpty) {
                  try {
                    final currentUser = Provider.of<AppState>(context, listen: false).currentUser;
                    if (currentUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please log in to create binders')),
                      );
                      return;
                    }

                    // Firestore: Create binder
                    await FirestoreService.binders.add({
                      'name': newBinderName,
                      'createdAt': FieldValue.serverTimestamp(),
                      'userId': currentUser.uid,
                      'albumName': widget.parentAlbumName,
                    });

                    // Update local state
                    setState(() {
                      binders.add(newBinderName);
                    });

                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Binder created successfully!')),
                    );
                  } catch (e) {
                    print('Error creating binder: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create binder: ${e.toString()}')),
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
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AlbumsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const Text(
                                    'Binders',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.titleText,
                                    ),
                                  ),
                                ],
                              ),
                              // Display binder name if available
                              if (widget.binderName != null && widget.binderName!.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Text(
                                  'Binder: ${widget.binderName}',
                                  style: const TextStyle(
                                    color: AppColors.titleText,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              // Display album name as main title when not in a notebook context
                              if (widget.parentAlbumName != null && widget.parentAlbumName!.isNotEmpty && 
                                  (widget.binderName == null || widget.binderName!.isEmpty)) ...[
                                const SizedBox(height: 20),
                                Text(
                                  widget.parentAlbumName!,
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
                // Right side - Binders grid
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24.0),
                    child: _buildBindersGrid(context),
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
                      'Create Binder',
                      Icons.create_new_folder,
                      () {
                        _createNewBinder();
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
                            'binderName': 'Unsorted', // Photos go to main grid
                            'albumName': widget.parentAlbumName,
                            'userId': currentUser.uid,
                            'source': PhotoSources.binders,
                          });

                          Navigator.pop(context); // Hide loading indicator
                          await _loadBinderPhotos(); // Reload photos

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
                // Display binder name if available
                if (widget.binderName != null && widget.binderName!.isNotEmpty) ...[
                  Text(
                    'Binder: ${widget.binderName}',
                    style: const TextStyle(
                      color: AppColors.titleText,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Display album name as main title when not in a notebook context
                if (widget.parentAlbumName != null && widget.parentAlbumName!.isNotEmpty && 
                    (widget.binderName == null || widget.binderName!.isEmpty)) ...[
                  Text(
                    widget.parentAlbumName!,
                    style: const TextStyle(
                      color: AppColors.titleText,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                // Binders Grid
                Expanded(
                  child: _buildBindersGrid(context),
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
              _createNewBinder();
            },
            icon: const Icon(Icons.create_new_folder),
            label: const Text('Create Binder'),
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
                  'binderName': 'Unsorted', // Photos go to main grid
                  'albumName': widget.parentAlbumName,
                  'userId': currentUser.uid,
                  'source': PhotoSources.binders,
                });

                Navigator.pop(context); // Hide loading indicator
                await _loadBinderPhotos(); // Reload photos

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

  Widget _buildBindersGrid(BuildContext context) {
    print('🎯 Building binders grid with ${binders.length} binders and ${binderPhotos['Unsorted']?.length ?? 0} unsorted photos');
    print('📊 Total binderPhotos keys: ${binderPhotos.keys.toList()}');
    return _isLoading && binderPhotos.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : GridView.builder(
            controller: _scrollController,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.isWideScreen(context) ? 4 : 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.75,
            ),
            itemCount: binders.length + (binderPhotos['Unsorted']?.length ?? 0) + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator at the end
              if (index == binders.length + (binderPhotos['Unsorted']?.length ?? 0)) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              // First show binders
              if (index < binders.length) {
                return _buildBinderCard(binders[index]);
              } 
              // Then show photos from main grid
              else {
                final photoIndex = index - binders.length;
                if (binderPhotos['Unsorted'] != null && 
                    photoIndex < binderPhotos['Unsorted']!.length) {
                  final photo = binderPhotos['Unsorted']![photoIndex];
                  return _buildPhotoCard(photo);
                }
                return const SizedBox();
              }
            },
          );
  }

  Widget _buildBinderCard(String binderName) {
    final photos = binderPhotos[binderName] ?? [];
    print('🎯 Building binder card for "$binderName" with ${photos.length} photos');
    if (photos.isNotEmpty) {
      print('📸 First photo URL: ${photos[0].firebaseUrl}');
    }
    
    return GestureDetector(
      onSecondaryTapDown: (details) => _showBinderContextMenu(context, details.globalPosition, binderName),
      onLongPress: () => _showBinderContextMenu(context, Offset(200, 200), binderName),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotebooksScreen(
                notebookName: binderName,
                parentBinderName: binderName,
                parentAlbumName: widget.parentAlbumName!,
                source: PhotoSources.notebooks,
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
                                photos[0].getImageUrl(size: 'thumbnail') ?? photos[0].firebaseUrl!,
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
              // Binder name overlay
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
                    binderName,
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
                          _editBinderName(binderName);
                          break;
                        case 'delete':
                          _deleteBinderWithContents(binderName);
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
                  photo.firebaseUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ Network image error: $error');
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
                    if (loadingProgress == null) {
                      return child;
                    }
                    return Container(
                      color: Colors.grey[300],
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

  Future<Uint8List?> _loadImageBytes(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error loading image bytes: $e');
    }
    return null;
  }

  Widget _buildFallbackImage(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        print('❌ Network image error: $error');
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
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: Colors.grey[300],
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

      // Firestore: Update photo
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

  void _showBinderContextMenu(BuildContext context, Offset position, String binderName) {
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
          onTap: () => _editBinderName(binderName),
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Folder'),
            ],
          ),
          onTap: () => _deleteBinderWithContents(binderName),
        ),
      ],
    );
  }

  Future<void> _editBinderName(String currentName) async {
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

        // Find the binder document
        final bindersQuery = await FirestoreService.binders
            .where('userId', isEqualTo: currentUser.uid)
            .where('albumName', isEqualTo: widget.parentAlbumName)
            .where('name', isEqualTo: currentName)
            .get();

        if (bindersQuery.docs.isNotEmpty) {
          final binderDoc = bindersQuery.docs.first;
          
          // Update binder name
          await FirestoreService.updateBinder(binderDoc.id, {'name': result});
          
          // Update all photos in this binder
          final photosQuery = await FirestoreService.photos
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: widget.parentAlbumName)
              .where('binderName', isEqualTo: currentName)
              .get();

          final batch = FirebaseFirestore.instance.batch();
          for (var doc in photosQuery.docs) {
            batch.update(doc.reference, {'binderName': result});
          }
          await batch.commit();

          // Update local state
          setState(() {
            final index = binders.indexOf(currentName);
            if (index != -1) {
              binders[index] = result;
              binderPhotos[result] = binderPhotos.remove(currentName) ?? [];
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder renamed to "$result"')),
          );
        }
      } catch (e) {
        print('Error renaming binder: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename folder: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteBinderWithContents(String binderName) async {
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
            'Are you sure you want to delete "$binderName" and all its contents? This action cannot be undone.',
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

        // Find the binder document
        final bindersQuery = await FirestoreService.binders
            .where('userId', isEqualTo: currentUser.uid)
            .where('albumName', isEqualTo: widget.parentAlbumName)
            .where('name', isEqualTo: binderName)
            .get();

        if (bindersQuery.docs.isNotEmpty) {
          final binderDoc = bindersQuery.docs.first;
          
          // Get all photos in this binder
          final photosQuery = await FirestoreService.photos
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: widget.parentAlbumName)
              .where('binderName', isEqualTo: binderName)
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

          // Delete notebooks in this binder
          final notebooksQuery = await FirestoreService.notebooks
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: widget.parentAlbumName)
              .where('binderName', isEqualTo: binderName)
              .get();

          for (var notebookDoc in notebooksQuery.docs) {
            batch.delete(notebookDoc.reference);
          }

          // Delete the binder document
          batch.delete(binderDoc.reference);
          
          // Commit all deletions
          await batch.commit();

          // Update local state
          setState(() {
            binders.remove(binderName);
            binderPhotos.remove(binderName);
          });

          Navigator.pop(context); // Hide loading indicator
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Folder "$binderName" and all contents deleted')),
          );
        }
      } catch (e) {
        Navigator.pop(context); // Hide loading indicator
        print('Error deleting binder: $e');
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
          // Remove photo from all binder collections
          for (var binderName in binderPhotos.keys) {
            binderPhotos[binderName]?.removeWhere((p) => p.id == photo.id);
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
    // For binders_screen, we need to get the current context from the widget properties
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return MovePhotoDialog(
          photo: photo,
          currentAlbumName: widget.parentAlbumName ?? 'Unsorted',
          currentBinderName: widget.binderName,
          currentNotebookName: null,
          sourceContext: 'binders',
        );
      },
    );
    
    // If photo was moved successfully, refresh the data
    if (result == true) {
      await _loadBinders();
      await _loadBinderPhotos();
    }
  }
} 