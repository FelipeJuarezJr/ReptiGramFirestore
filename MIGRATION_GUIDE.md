# Firebase Realtime Database to Firestore Migration Guide

## Overview
This guide documents the migration of ReptiGram from Firebase Realtime Database to Firestore.

## Changes Made

### 1. Dependencies Updated
- **Removed**: `firebase_database: ^10.3.8`
- **Added**: `firebase_firestore: ^4.13.6`

### 2. Firebase Configuration
- Updated `lib/firebase_options.dart` with new Firestore project configuration
- Removed `databaseURL` (not needed for Firestore)

### 3. New Firestore Service
Created `lib/services/firestore_service.dart` with centralized database operations:
- User management (create, read, update)
- Post operations (create, read, update, delete)
- Like/comment functionality
- Photo management
- Binder/Album/Notebook operations
- Batch operations for better performance

### 4. Migrated Files

#### Core State Management
- ✅ `lib/state/auth_state.dart` - User authentication and profile management
- ✅ `lib/state/app_state.dart` - Application state and user data
- ✅ `lib/utils/photo_utils.dart` - Photo utility functions

#### Authentication Screens
- ✅ `lib/screens/login_screen.dart` - Login functionality
- ✅ `lib/screens/register_screen.dart` - User registration

#### Remaining Files to Migrate
- ⏳ `lib/screens/feed_screen.dart` - Main feed with posts
- ⏳ `lib/screens/post_screen.dart` - Individual post view
- ⏳ `lib/screens/photos_only_screen.dart` - Photo gallery
- ⏳ `lib/screens/albums_screen.dart` - Album management
- ⏳ `lib/screens/notebooks_screen.dart` - Notebook management
- ⏳ `lib/screens/binders_screen.dart` - Binder management
- ⏳ `lib/screens/registration_screen.dart` - Alternative registration

## Database Structure Changes

### Realtime Database → Firestore Collections

| Realtime Database Path | Firestore Collection | Notes |
|------------------------|---------------------|-------|
| `/users/{uid}` | `users/{uid}` | User profiles |
| `/usernames/{username}` | `usernames/{username}` | Username reservations |
| `/posts/{postId}` | `posts/{postId}` | Posts with subcollections |
| `/posts/{postId}/likes/{userId}` | `posts/{postId}/likes/{userId}` | Post likes |
| `/posts/{postId}/comments/{commentId}` | `posts/{postId}/comments/{commentId}` | Post comments |
| `/photos/{photoId}` | `photos/{photoId}` | Photo metadata |
| `/binders/{binderId}` | `binders/{binderId}` | Binder collections |
| `/albums/{albumId}` | `albums/{albumId}` | Album collections |
| `/notebooks/{notebookId}` | `notebooks/{notebookId}` | Notebook collections |

## Key Differences

### 1. Data Structure
- **Realtime Database**: JSON tree structure
- **Firestore**: Document-based with collections and subcollections

### 2. Queries
- **Realtime Database**: Limited querying capabilities
- **Firestore**: Rich querying with multiple filters, ordering, and pagination

### 3. Real-time Updates
- **Realtime Database**: `.onValue` listeners
- **Firestore**: `.snapshots()` streams

### 4. Batch Operations
- **Realtime Database**: Individual operations
- **Firestore**: Batch writes for better performance and consistency

### 5. Timestamps
- **Realtime Database**: `ServerValue.timestamp`
- **Firestore**: `FieldValue.serverTimestamp()`

## Migration Steps for Remaining Files

### 1. Update Imports
```dart
// Remove
import 'package:firebase_database/firebase_database.dart';

// Add
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
```

### 2. Replace Database Operations

#### Reading Data
```dart
// Old (Realtime Database)
final snapshot = await FirebaseDatabase.instance
    .ref()
    .child('users')
    .child(uid)
    .get();

// New (Firestore)
final doc = await FirestoreService.getUser(uid);
```

#### Writing Data
```dart
// Old (Realtime Database)
await FirebaseDatabase.instance
    .ref()
    .child('users')
    .child(uid)
    .set(userData);

// New (Firestore)
await FirestoreService.createUser(user);
```

#### Real-time Listeners
```dart
// Old (Realtime Database)
StreamBuilder<DatabaseEvent>(
  stream: FirebaseDatabase.instance
      .ref()
      .child('posts')
      .onValue,
  builder: (context, snapshot) { ... }
)

// New (Firestore)
StreamBuilder<QuerySnapshot>(
  stream: FirestoreService.getPostsStream(),
  builder: (context, snapshot) { ... }
)
```

### 3. Update Timestamps
```dart
// Old (Realtime Database)
'timestamp': ServerValue.timestamp,

// New (Firestore)
'timestamp': FirestoreService.serverTimestamp,
```

## Testing Checklist

- [ ] User registration works
- [ ] User login works
- [ ] Username availability checking works
- [ ] User profile updates work
- [ ] Posts can be created and read
- [ ] Likes and comments work
- [ ] Photos can be uploaded and managed
- [ ] Real-time updates work
- [ ] Batch operations work correctly

## Performance Considerations

1. **Indexes**: Firestore may require composite indexes for complex queries
2. **Pagination**: Use `limit()` and `startAfter()` for large datasets
3. **Offline Support**: Firestore provides better offline capabilities
4. **Security Rules**: Update Firestore security rules accordingly

## Next Steps

1. Complete migration of remaining screen files
2. Update Firestore security rules
3. Test all functionality thoroughly
4. Set up proper indexes for queries
5. Monitor performance and costs
6. Remove old Realtime Database code

## Rollback Plan

If issues arise, you can:
1. Keep both database implementations temporarily
2. Use feature flags to switch between databases
3. Gradually migrate features back if needed
4. Maintain data synchronization between both databases during transition 