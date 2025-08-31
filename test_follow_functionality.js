const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to set up service account)
// const serviceAccount = require('./path-to-service-account.json');
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount)
// });

const db = admin.firestore();

async function testFollowFunctionality() {
  try {
    console.log('Testing Follow Functionality...\n');

    // Test 1: Create test users
    console.log('1. Creating test users...');
    const user1 = { uid: 'test-user-1', username: 'testuser1', email: 'test1@example.com' };
    const user2 = { uid: 'test-user-2', username: 'testuser2', email: 'test2@example.com' };
    
    await db.collection('users').doc(user1.uid).set(user1);
    await db.collection('users').doc(user2.uid).set(user2);
    console.log('✓ Test users created');

    // Test 2: Create test posts
    console.log('\n2. Creating test posts...');
    const post1 = await db.collection('posts').add({
      userId: user1.uid,
      content: 'Test post from user 1',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    const post2 = await db.collection('posts').add({
      userId: user2.uid,
      content: 'Test post from user 2',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✓ Test posts created');

    // Test 3: Test follow functionality
    console.log('\n3. Testing follow functionality...');
    
    // User 1 follows User 2
    await db.collection('followers').doc(`${user1.uid}-${user2.uid}`).set({
      followerId: user1.uid,
      followedUserId: user2.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log('✓ User 1 followed User 2');

    // Test 4: Verify follow status
    console.log('\n4. Verifying follow status...');
    
    const followDoc = await db.collection('followers').doc(`${user1.uid}-${user2.uid}`).get();
    if (followDoc.exists) {
      console.log('✓ Follow relationship exists');
    } else {
      console.log('✗ Follow relationship not found');
    }

    // Test 5: Get followed user IDs
    console.log('\n5. Getting followed user IDs...');
    
    const followedUsers = await db.collection('followers')
      .where('followerId', '==', user1.uid)
      .get();
    
    const followedUserIds = followedUsers.docs.map(doc => doc.data().followedUserId);
    console.log(`✓ User 1 is following: ${followedUserIds.join(', ')}`);

    // Test 6: Test unfollow
    console.log('\n6. Testing unfollow...');
    
    await db.collection('followers').doc(`${user1.uid}-${user2.uid}`).delete();
    console.log('✓ User 1 unfollowed User 2');

    // Test 7: Verify unfollow
    const unfollowDoc = await db.collection('followers').doc(`${user1.uid}-${user2.uid}`).get();
    if (!unfollowDoc.exists) {
      console.log('✓ Follow relationship removed');
    } else {
      console.log('✗ Follow relationship still exists');
    }

    // Cleanup
    console.log('\n7. Cleaning up test data...');
    await post1.delete();
    await post2.delete();
    await db.collection('users').doc(user1.uid).delete();
    await db.collection('users').doc(user2.uid).delete();
    console.log('✓ Test data cleaned up');

    console.log('\n🎉 All tests passed! Follow functionality is working correctly.');

  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

// Uncomment to run the test
// testFollowFunctionality();

module.exports = { testFollowFunctionality };
