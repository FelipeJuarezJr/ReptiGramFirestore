import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/photo_data.dart';
import '../services/firestore_service.dart';
import '../styles/colors.dart';

class MovePhotoDialog extends StatefulWidget {
  final PhotoData photo;
  final String currentAlbumName;
  final String? currentBinderName;
  final String? currentNotebookName;
  final String? sourceContext; // 'albums', 'binders', 'notebooks', 'photosOnly'

  const MovePhotoDialog({
    Key? key,
    required this.photo,
    required this.currentAlbumName,
    this.currentBinderName,
    this.currentNotebookName,
    this.sourceContext,
  }) : super(key: key);

  @override
  State<MovePhotoDialog> createState() => _MovePhotoDialogState();
}

class _MovePhotoDialogState extends State<MovePhotoDialog> {
  List<String> albums = [];
  Map<String, List<String>> albumBinders = {};
  Map<String, Map<String, List<String>>> albumBinderNotebooks = {};
  
  String? selectedAlbum;
  String? selectedBinder;
  String? selectedNotebook;
  
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Load albums
      final albumsQuery = await FirestoreService.albums
          .where('userId', isEqualTo: currentUser.uid)
          .get();
      
      albums = albumsQuery.docs.map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String).toList();
      
      // Load binders for each album
      for (String albumName in albums) {
        final bindersQuery = await FirestoreService.binders
            .where('userId', isEqualTo: currentUser.uid)
            .where('albumName', isEqualTo: albumName)
            .get();
        
        albumBinders[albumName] = bindersQuery.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
            .toList();
        
        // Load notebooks for each binder
        albumBinderNotebooks[albumName] = {};
        for (String binderName in albumBinders[albumName]!) {
          final notebooksQuery = await FirestoreService.notebooks
              .where('userId', isEqualTo: currentUser.uid)
              .where('albumName', isEqualTo: albumName)
              .where('binderName', isEqualTo: binderName)
              .get();
          
          albumBinderNotebooks[albumName]![binderName] = notebooksQuery.docs
              .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String)
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.dialogBackground,
      title: const Text(
        'Move Photo',
        style: TextStyle(color: AppColors.titleText),
      ),
      content: SizedBox(
        width: 400,
        height: 500,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red)))
                : _buildFolderSelector(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.brown,
          ),
        ),
        TextButton(
          onPressed: _canMove() ? _movePhoto : null,
          child: const Text('Move'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildFolderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select destination folder:',
          style: TextStyle(
            color: AppColors.titleText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Show context-specific options
        Expanded(
          child: _buildContextSpecificOptions(),
        ),
      ],
    );
  }

  Widget _buildContextSpecificOptions() {
    return _buildUnifiedMainScreenOptions();
  }

  Widget _buildUnifiedMainScreenOptions() {
    return Column(
      children: [
        // Only show albums with their binders and notebooks
        Expanded(
          child: ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumName = albums[index];
              return _buildAlbumTile(albumName);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsContextOptions() {
    return Column(
      children: [
        // Albums Main (for unsorted images)
        _buildDestinationOption(
          'Albums Main',
          'Move to main albums grid',
          Icons.folder_open,
          Colors.blue,
          () => _selectDestination(widget.currentAlbumName, null, null),
        ),
        const SizedBox(height: 8),
        // All albums
        Expanded(
          child: ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumName = albums[index];
              return _buildAlbumTile(albumName);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBindersContextOptions() {
    return Column(
      children: [
        // Binders Main (for unsorted images)
        _buildDestinationOption(
          'Binders Main',
          'Move to main binders grid',
          Icons.folder_open,
          Colors.green,
          () => _selectDestination(widget.currentAlbumName, null, null),
        ),
        const SizedBox(height: 8),
        // All albums with their binders
        Expanded(
          child: ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumName = albums[index];
              return _buildAlbumTile(albumName);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotebooksContextOptions() {
    return Column(
      children: [
        // Notebooks Main (for unsorted images)
        _buildDestinationOption(
          'Notebooks Main',
          'Move to main notebooks grid',
          Icons.book,
          Colors.orange,
          () => _selectDestination(widget.currentAlbumName, widget.currentBinderName, null),
        ),
        const SizedBox(height: 8),
        // All albums with their binders and notebooks
        Expanded(
          child: ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumName = albums[index];
              return _buildAlbumTile(albumName);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosOnlyContextOptions() {
    return Column(
      children: [
        // Photos Only Main
        _buildDestinationOption(
          'Photos Only',
          'Move to main photos grid',
          Icons.photo_library,
          Colors.purple,
          () => _selectDestination('Photos Only', null, null),
        ),
        const SizedBox(height: 8),
        // All albums with their binders and notebooks
        Expanded(
          child: ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final albumName = albums[index];
              return _buildAlbumTile(albumName);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.titleText,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(subtitle),
        onTap: onTap,
        selected: _isSelected(title),
      ),
    );
  }

  bool _isSelected(String title) {
    // Main screen options removed - only album/binder/notebook selections remain
    return false;
  }

  Widget _buildAlbumTile(String albumName) {
    final isExpanded = selectedAlbum == albumName;
    final binders = albumBinders[albumName] ?? [];
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text(
          albumName,
          style: TextStyle(
            color: AppColors.titleText,
            fontWeight: selectedAlbum == albumName ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        leading: const Icon(Icons.folder, color: Colors.blue),
        onExpansionChanged: (expanded) {
          if (mounted) {
            setState(() {
              if (expanded) {
                selectedAlbum = albumName;
                selectedBinder = null;
                selectedNotebook = null;
              } else {
                selectedAlbum = null;
                selectedBinder = null;
                selectedNotebook = null;
              }
            });
          }
        },
        children: [
          if (isExpanded) ...[
            // Album level option
            ListTile(
              leading: const Icon(Icons.folder_open, color: Colors.blue),
              title: Text('$albumName (Album)'),
              onTap: () => _selectDestination(albumName, null, null),
              selected: selectedAlbum == albumName && selectedBinder == null,
            ),
            // Binders
            ...binders.map((binderName) => _buildBinderTile(albumName, binderName)),
          ],
        ],
      ),
    );
  }

  Widget _buildBinderTile(String albumName, String binderName) {
    final isExpanded = selectedAlbum == albumName && selectedBinder == binderName;
    final notebooks = albumBinderNotebooks[albumName]?[binderName] ?? [];
    
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: ExpansionTile(
          title: Text(
            binderName,
            style: TextStyle(
              color: AppColors.titleText,
              fontWeight: selectedBinder == binderName ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          leading: const Icon(Icons.folder, color: Colors.green),
          onExpansionChanged: (expanded) {
            if (mounted) {
              setState(() {
                if (expanded) {
                  selectedAlbum = albumName;
                  selectedBinder = binderName;
                  selectedNotebook = null;
                } else if (selectedBinder == binderName) {
                  selectedBinder = null;
                  selectedNotebook = null;
                }
              });
            }
          },
          children: [
            if (isExpanded) ...[
              // Binder level option
              ListTile(
                leading: const Icon(Icons.folder_open, color: Colors.green),
                title: Text('$binderName (Binder)'),
                onTap: () => _selectDestination(albumName, binderName, null),
                selected: selectedAlbum == albumName && selectedBinder == binderName && selectedNotebook == null,
              ),
              // Notebooks
              ...notebooks.map((notebookName) => _buildNotebookTile(albumName, binderName, notebookName)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotebookTile(String albumName, String binderName, String notebookName) {
    return Padding(
      padding: const EdgeInsets.only(left: 32),
      child: ListTile(
        leading: const Icon(Icons.book, color: Colors.orange),
        title: Text(notebookName),
        onTap: () => _selectDestination(albumName, binderName, notebookName),
        selected: selectedAlbum == albumName && 
                  selectedBinder == binderName && 
                  selectedNotebook == notebookName,
      ),
    );
  }

  void _selectDestination(String albumName, String? binderName, String? notebookName) {
    if (mounted) {
      setState(() {
        selectedAlbum = albumName;
        selectedBinder = binderName;
        selectedNotebook = notebookName;
      });
    }
  }

  bool _canMove() {
    if (selectedAlbum == null) return false;
    
    // Check if we're moving to a different location
    // Only allow moving to specific album/binder/notebook combinations
    return selectedAlbum != widget.currentAlbumName ||
           selectedBinder != widget.currentBinderName ||
           selectedNotebook != widget.currentNotebookName;
  }

  Future<void> _movePhoto() async {
    if (!_canMove()) return;

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

      // Moving to a specific album/binder/notebook
      final destinationAlbum = selectedAlbum!;
      final destinationBinder = selectedBinder;
      final destinationNotebook = selectedNotebook;

      // Update photo document in Firestore
      await FirestoreService.movePhoto(
        widget.photo.id,
        destinationAlbum,
        destinationBinder,
        destinationNotebook,
      );

      Navigator.pop(context); // Hide loading indicator
      Navigator.pop(context, true); // Close dialog and return true to indicate success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo moved to $selectedAlbum${selectedBinder != null ? ' > $selectedBinder' : ''}${selectedNotebook != null ? ' > $selectedNotebook' : ''}'),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Hide loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to move photo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

}
