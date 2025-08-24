# ReptiGram Follow Feature Implementation

This document describes the implementation of the follow feature in ReptiGram, which allows users to follow other users and see their posts in a personalized timeline.

## 🏗️ Architecture Overview

The follow feature uses a **subcollection-based approach** with **timeline denormalization** for optimal performance:

### Data Structure
```
users/{userId}
├── following/{followedUserId}
│   └── createdAt: timestamp
├── followers/{followerUserId}
│   └── createdAt: timestamp
└── timeline/{postId}
    ├── userId: string
    ├── content: string
    ├── timestamp: timestamp
    ├── imageUrl: string?
    ├── authorUsername: string
    ├── authorPhotoUrl: string?
    └── ... (other post fields)
```

### Key Components
1. **FollowService** - Handles follow/unfollow operations
2. **Cloud Functions** - Automatically copy posts to followers' timelines
3. **Timeline Feed** - Shows posts from followed users
4. **User Discovery** - Find users to follow
5. **Follow Button** - Reusable follow/unfollow UI component

## 🚀 Getting Started

### 1. Deploy Cloud Functions
The follow feature requires Cloud Functions to automatically copy posts to followers' timelines.

```bash
cd functions
npm install
firebase deploy --only functions
```

### 2. Update Firestore Rules
Ensure your Firestore rules allow access to the new collections:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Allow reading other users' basic info
      allow read: if request.auth != null;
      
      // Following/Followers subcollections
      match /following/{followedUserId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /followers/{followerUserId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == followerUserId;
      }
      
      // Timeline subcollection
      match /timeline/{postId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Posts collection
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == resource.data.userId;
      allow update, delete: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

## 📱 Usage

### Following a User
```dart
// Follow a user
await FollowService.followUser(targetUserId);

// Check if following
bool isFollowing = await FollowService.isFollowing(targetUserId);

// Get follow counts
Map<String, int> counts = await FollowService.getFollowCounts(userId);
```

### Using the Follow Button Widget
```dart
FollowButton(
  targetUserId: user.uid,
  isFollowing: isFollowing,
  onFollowChanged: () {
    // Handle follow state change
    setState(() {});
  },
)
```

### Displaying User Profile Cards
```dart
UserProfileCard(
  user: user,
  isFollowing: isFollowing,
  onFollowChanged: () {
    // Handle follow state change
  },
  onTap: () {
    // Navigate to user profile
  },
)
```

### Getting Timeline Posts
```dart
// Stream of posts from followed users
Stream<List<PostModel>> timelineStream = FollowService.getUserTimelineStream();

// Or use the FirestoreService
Stream<QuerySnapshot> timelineStream = FirestoreService.getUserTimelineStream();
```

## 🔧 API Reference

### FollowService

#### Methods
- `followUser(String targetUserId)` - Follow a user
- `unfollowUser(String targetUserId)` - Unfollow a user
- `isFollowing(String targetUserId)` - Check follow status
- `getFollowingStream()` - Stream of users being followed
- `getFollowersStream()` - Stream of followers
- `getUserTimelineStream()` - Stream of timeline posts
- `getFollowCounts(String userId)` - Get follower/following counts
- `getFollowSuggestions({int limit})` - Get user suggestions

### FirestoreService

#### New Methods
- `followUser(String targetUserId)` - Follow a user
- `unfollowUser(String targetUserId)` - Unfollow a user
- `isFollowing(String targetUserId)` - Check follow status
- `getUserTimelineStream()` - Get timeline stream
- `getFollowCounts(String userId)` - Get follow counts

#### Enhanced Methods
- `createPost()` - Now includes author information
- `createPhoto()` - Now includes author information

## 🌟 Features

### 1. Follow/Unfollow Users
- One-click follow/unfollow
- Real-time follow status updates
- Follow count tracking

### 2. Timeline Feed
- Shows posts from followed users only
- Real-time updates when followed users post
- Efficient querying using subcollections

### 3. User Discovery
- Find users to follow
- Search functionality
- Follow suggestions

### 4. Performance Optimizations
- Timeline denormalization for fast queries
- Batched writes for follow operations
- Cloud Functions for automatic timeline updates

## 🔄 How It Works

### Follow Process
1. User clicks follow button
2. `FollowService.followUser()` is called
3. Batch write updates both users' collections
4. Follow counts are incremented
5. UI updates to show "Unfollow" button

### Timeline Fan-out
1. User creates a post
2. Cloud Function triggers on post creation
3. Function finds all followers of the author
4. Post is copied to each follower's timeline
5. Followers see the post in their timeline immediately

### Unfollow Process
1. User clicks unfollow button
2. `FollowService.unfollowUser()` is called
3. Batch write removes from both collections
4. Follow counts are decremented
5. UI updates to show "Follow" button

## 🧪 Testing

Use the provided test script to verify the follow functionality:

```bash
# Set up Firebase Admin SDK
# Update test user IDs in test_follow_feature.js
node test_follow_feature.js
```

## 📊 Performance Considerations

### Scalability
- **Timeline denormalization** allows unlimited followers without query limits
- **Batched writes** ensure atomic operations
- **Cloud Functions** handle heavy lifting asynchronously

### Storage
- Each post is duplicated across multiple timelines
- Storage cost increases with follower count
- Consider cleanup strategies for inactive users

### Query Performance
- Timeline queries are O(1) - no complex joins
- Follow status checks are O(1) - direct document lookup
- Follow counts are pre-computed and updated in real-time

## 🚨 Limitations & Considerations

### Current Limitations
- Old posts remain in timelines when unfollowing (by design)
- No follow request/approval system
- No private accounts

### Future Enhancements
- Follow request system
- Private accounts
- Mute/unmute users
- Follow categories (close friends, family, etc.)
- Timeline cleanup for unfollowed users

## 🔐 Security

### Data Access
- Users can only modify their own follow relationships
- Timeline data is private to each user
- Follow counts are publicly readable

### Validation
- All operations require authentication
- User IDs are validated before operations
- Batch operations ensure data consistency

## 📝 Migration Notes

### For Existing Users
- New users automatically get `followersCount: 0` and `followingCount: 0`
- Existing users need these fields added manually or via migration script

### For Existing Posts
- Only new posts are automatically added to timelines
- Consider running a one-time migration for existing posts

## 🆘 Troubleshooting

### Common Issues

#### Follow button not working
- Check if user is authenticated
- Verify Firestore rules allow the operation
- Check console for error messages

#### Timeline not showing posts
- Ensure Cloud Functions are deployed
- Check if posts have `userId` field
- Verify timeline subcollections exist

#### Follow counts not updating
- Check if batch operations are completing
- Verify Firestore rules allow count updates
- Check console for permission errors

### Debug Commands
```bash
# Check Cloud Function logs
firebase functions:log

# Test Firestore rules
firebase firestore:rules:test

# Deploy only functions
firebase deploy --only functions
```

## 📚 Additional Resources

- [Firestore Subcollections Guide](https://firebase.google.com/docs/firestore/data-model#subcollections)
- [Cloud Functions Documentation](https://firebase.google.com/docs/functions)
- [Flutter Firestore Package](https://pub.dev/packages/cloud_firestore)

## 🤝 Contributing

When contributing to the follow feature:

1. Follow the existing code style
2. Add tests for new functionality
3. Update this documentation
4. Test with real Firestore data
5. Consider performance implications

---

**Note**: This feature is designed to scale to thousands of followers per user while maintaining fast query performance. The timeline denormalization approach trades storage for speed, which is the recommended pattern for social media applications.
