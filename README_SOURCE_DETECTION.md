# Automatic Source Detection Implementation

## Overview
Each screen now automatically detects its source type and uses it for:
1. **Firestore Queries**: Only loads photos with the correct source
2. **Photo Uploads**: Automatically tags uploaded photos with the correct source
3. **Navigation**: Passes the correct source to child screens

## Implementation Details

### 1. Constants File (`lib/constants/photo_sources.dart`)
```dart
class PhotoSources {
  static const albums = 'albums';
  static const binders = 'binders';
  static const notebooks = 'notebooks';
  static const photosOnly = 'photosOnly';
  
  static String getScreenTitle(String source) {
    switch (source) {
      case binders: return 'Binders';
      case notebooks: return 'Notebooks';
      case photosOnly: return 'Photos';
      case albums:
      default: return 'Albums';
    }
  }
}
```

### 2. Screen Updates

#### AlbumsScreen
- **Constructor**: `AlbumsScreen({source = PhotoSources.albums})`
- **Query**: `.where('source', isEqualTo: widget.source)`
- **Upload**: `'source': widget.source`

#### BindersScreen
- **Constructor**: `BindersScreen({source = PhotoSources.binders})`
- **Query**: `.where('source', isEqualTo: widget.source)`
- **Upload**: `'source': widget.source`

#### NotebooksScreen
- **Constructor**: `NotebooksScreen({source = PhotoSources.notebooks})`
- **Query**: `.where('source', isEqualTo: widget.source)`
- **Upload**: `'source': widget.source`

#### PhotosOnlyScreen
- **Constructor**: `PhotosOnlyScreen({source = PhotoSources.photosOnly})`
- **Query**: `.where('source', isEqualTo: widget.source)`
- **Upload**: `'source': widget.source`

### 3. Navigation Updates

#### AlbumsScreen → BindersScreen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => BindersScreen(
      binderName: 'My Binder',
      parentAlbumName: albumName,
      source: PhotoSources.binders, // ✅ Correct source
    ),
  ),
);
```

#### BindersScreen → NotebooksScreen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => NotebooksScreen(
      notebookName: 'My Notebook',
      parentBinderName: binderName,
      parentAlbumName: widget.parentAlbumName!,
      source: PhotoSources.notebooks, // ✅ Correct source
    ),
  ),
);
```

#### NotebooksScreen → PhotosOnlyScreen
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => PhotosOnlyScreen(
      notebookName: notebookName,
      parentBinderName: widget.parentBinderName,
      parentAlbumName: widget.parentAlbumName,
      source: PhotoSources.photosOnly, // ✅ Correct source
    ),
  ),
);
```

## Benefits

1. **Automatic Source Detection**: Each screen knows its own source type
2. **Consistent Data**: Photos are always tagged with the correct source
3. **Proper Filtering**: Each screen only shows its relevant photos
4. **Maintainable**: Centralized constants prevent typos
5. **Extensible**: Easy to add new source types

## Usage Example

When you upload a photo in any screen:
1. The screen automatically uses its `widget.source` value
2. The photo is saved to Firestore with the correct source
3. The photo will only appear in screens that query for that source
4. Navigation to child screens passes the correct source automatically

## Testing

To verify it's working:
1. Upload a photo in AlbumsScreen → Check Firestore has `source: 'albums'`
2. Upload a photo in BindersScreen → Check Firestore has `source: 'binders'`
3. Upload a photo in NotebooksScreen → Check Firestore has `source: 'notebooks'`
4. Upload a photo in PhotosOnlyScreen → Check Firestore has `source: 'photosOnly'`

Each screen should only show photos with its corresponding source. 