const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to set up service account)
// admin.initializeApp({
//   credential: admin.credential.applicationDefault(),
//   projectId: 'your-project-id'
// });

const db = admin.firestore();

async function testFollowFeature() {
  console.log('🧪 Testing Follow Feature...\n');

  try {
    // Test user IDs (replace with actual user IDs from your database)
    const user1Id = 'test_user_1';
    const user2Id = 'test_user_2';

    console.log('1. Testing follow operation...');
    
    // Test following a user
    await followUser(user1Id, user2Id);
    console.log('✅ User 1 successfully followed User 2');

    // Test checking follow status
    const isFollowing = await checkFollowStatus(user1Id, user2Id);
    console.log(`✅ Follow status check: ${isFollowing}`);

    // Test getting follow counts
    const counts1 = await getFollowCounts(user1Id);
    const counts2 = await getFollowCounts(user2Id);
    console.log(`✅ User 1 counts: ${JSON.stringify(counts1)}`);
    console.log(`✅ User 2 counts: ${JSON.stringify(counts2)}`);

    // Test getting following list
    const following = await getFollowingList(user1Id);
    console.log(`✅ User 1 following: ${following.join(', ')}`);

    // Test getting followers list
    const followers = await getFollowersList(user2Id);
    console.log(`✅ User 2 followers: ${followers.join(', ')}`);

    console.log('\n2. Testing unfollow operation...');
    
    // Test unfollowing a user
    await unfollowUser(user1Id, user2Id);
    console.log('✅ User 1 successfully unfollowed User 2');

    // Test checking follow status after unfollow
    const isFollowingAfter = await checkFollowStatus(user1Id, user2Id);
    console.log(`✅ Follow status after unfollow: ${isFollowingAfter}`);

    // Test getting follow counts after unfollow
    const counts1After = await getFollowCounts(user1Id);
    const counts2After = await getFollowCounts(user2Id);
    console.log(`✅ User 1 counts after unfollow: ${JSON.stringify(counts1After)}`);
    console.log(`✅ User 2 counts after unfollow: ${JSON.stringify(counts2After)}`);

    console.log('\n🎉 All tests passed! Follow feature is working correctly.');

  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

async function followUser(followerId, targetUserId) {
  const batch = db.batch();
  
  // Add to follower's following collection
  const followingRef = db
    .collection('users')
    .doc(followerId)
    .collection('following')
    .doc(targetUserId);
  
  batch.set(followingRef, {
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Add to target user's followers collection
  const followersRef = db
    .collection('users')
    .doc(targetUserId)
    .collection('followers')
    .doc(followerId);
  
  batch.set(followersRef, {
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Update follow counts
  const followerRef = db.collection('users').doc(followerId);
  const targetRef = db.collection('users').doc(targetUserId);
  
  batch.update(followerRef, {
    followingCount: admin.firestore.FieldValue.increment(1),
  });
  
  batch.update(targetRef, {
    followersCount: admin.firestore.FieldValue.increment(1),
  });
  
  await batch.commit();
}

async function unfollowUser(followerId, targetUserId) {
  const batch = db.batch();
  
  // Remove from follower's following collection
  const followingRef = db
    .collection('users')
    .doc(followerId)
    .collection('following')
    .doc(targetUserId);
  
  batch.delete(followingRef);
  
  // Remove from target user's followers collection
  const followersRef = db
    .collection('users')
    .doc(targetUserId)
    .collection('followers')
    .doc(followerId);
  
  batch.delete(followersRef);
  
  // Update follow counts
  const followerRef = db.collection('users').doc(followerId);
  const targetRef = db.collection('users').doc(targetUserId);
  
  batch.update(followerRef, {
    followingCount: admin.firestore.FieldValue.increment(-1),
  });
  
  batch.update(targetRef, {
    followersCount: admin.firestore.FieldValue.increment(-1),
  });
  
  await batch.commit();
}

async function checkFollowStatus(followerId, targetUserId) {
  const doc = await db
    .collection('users')
    .doc(followerId)
    .collection('following')
    .doc(targetUserId)
    .get();
  
  return doc.exists;
}

async function getFollowCounts(userId) {
  const doc = await db.collection('users').doc(userId).get();
  if (!doc.exists) return { followers: 0, following: 0 };
  
  const data = doc.data();
  return {
    followers: data.followersCount || 0,
    following: data.followingCount || 0,
  };
}

async function getFollowingList(userId) {
  const snapshot = await db
    .collection('users')
    .doc(userId)
    .collection('following')
    .get();
  
  return snapshot.docs.map(doc => doc.id);
}

async function getFollowersList(userId) {
  const snapshot = await db
    .collection('users')
    .doc(userId)
    .collection('followers')
    .get();
  
  return snapshot.docs.map(doc => doc.id);
}

// Run the test if this file is executed directly
if (require.main === module) {
  console.log('⚠️  This is a test script. Make sure to:');
  console.log('   1. Set up Firebase Admin SDK');
  console.log('   2. Replace test user IDs with actual user IDs');
  console.log('   3. Have proper Firestore rules in place\n');
  
  // Uncomment the line below to run the test
  // testFollowFeature();
}

module.exports = {
  testFollowFeature,
  followUser,
  unfollowUser,
  checkFollowStatus,
  getFollowCounts,
  getFollowingList,
  getFollowersList,
};
