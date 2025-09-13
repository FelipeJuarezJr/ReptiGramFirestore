import 'package:flutter/material.dart';
import '../models/photo_data.dart';
import '../services/paginated_photos_service.dart';

class InfiniteScrollGrid extends StatefulWidget {
  final List<PhotoData> photos;
  final Function(List<PhotoData>) onPhotosUpdated;
  final Function(PhotoData) onPhotoTap;
  final Function(PhotoData) onLikePhoto;
  final Function(PhotoData) onCommentPhoto;

  const InfiniteScrollGrid({
    Key? key,
    required this.photos,
    required this.onPhotosUpdated,
    required this.onPhotoTap,
    required this.onLikePhoto,
    required this.onCommentPhoto,
  }) : super(key: key);

  @override
  State<InfiniteScrollGrid> createState() => _InfiniteScrollGridState();
}

class _InfiniteScrollGridState extends State<InfiniteScrollGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePhotos();
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_isLoadingMore || !PaginatedPhotosService.hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newPhotos = await PaginatedPhotosService.loadPhotos();
      if (newPhotos.isNotEmpty) {
        widget.onPhotosUpdated([...widget.photos, ...newPhotos]);
      }
    } catch (e) {
      print('❌ Error loading more photos: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              childAspectRatio: 1.0,
            ),
            itemCount: widget.photos.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == widget.photos.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final photo = widget.photos[index];
              return _buildPhotoCard(photo);
            },
          ),
        ),
        if (!PaginatedPhotosService.hasMoreData && widget.photos.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'No more photos to load',
              style: TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoCard(PhotoData photo) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onPhotoTap(photo),
        child: Stack(
          children: [
            // Photo
            if (photo.firebaseUrl != null)
              Image.network(
                photo.getImageUrl(size: 'thumbnail') ?? photo.firebaseUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 50),
                  );
                },
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 50),
              ),

            // Like button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => widget.onLikePhoto(photo),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    photo.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: photo.isLiked ? Colors.red : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // Like count
            if (photo.likesCount > 0)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${photo.likesCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Comment button
            Positioned(
              bottom: 8,
              left: 8,
              child: GestureDetector(
                onTap: () => widget.onCommentPhoto(photo),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.comment,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}