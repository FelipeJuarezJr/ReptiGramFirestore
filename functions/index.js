const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send push notification when a new message is created
exports.sendChatNotification = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const chatId = context.params.chatId;
    
    // Don't send notification if it's a system message
    if (messageData.messageType === 'system') {
      return null;
    }

    try {
      // Extract user IDs from chat ID (format: uid1_uid2)
      const userIds = chatId.split('_');
      const senderId = messageData.senderId;
      const recipientId = userIds.find(id => id !== senderId);

      if (!recipientId) {
        console.log('Recipient not found');
        return null;
      }

      // Get recipient's FCM token
      const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
      if (!recipientDoc.exists) {
        console.log('Recipient user document not found');
        return null;
      }

      const recipientData = recipientDoc.data();
      const fcmToken = recipientData.fcmToken;

      if (!fcmToken) {
        console.log('Recipient FCM token not found');
        return null;
      }

      // Get sender's information
      const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
      let senderName = 'Someone';
      if (senderDoc.exists) {
        const senderData = senderDoc.data();
        senderName = senderData.username || senderData.displayName || 'Someone';
      }

      // Prepare notification content based on message type
      let notificationTitle = `New message from ${senderName}`;
      let notificationBody = '';

      switch (messageData.messageType) {
        case 'image':
          notificationBody = '📷 Sent you an image';
          break;
        case 'file':
          notificationBody = `📎 Sent you a file: ${messageData.fileName || 'File'}`;
          break;
        default:
          notificationBody = messageData.text || 'New message';
          break;
      }

      // Create the message using FCM v1 API
      const message = {
        token: fcmToken,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          senderId: senderId,
          messageType: messageData.messageType || 'text',
          chatId: chatId,
          messageId: context.params.messageId,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          notification: {
            sound: 'default',
            channelId: 'chat_messages',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
        webpush: {
          notification: {
            title: notificationTitle,
            body: notificationBody,
            icon: '/favicon.png',
            badge: '/favicon.png',
            tag: 'chat-message',
            requireInteraction: true,
            renotify: true,
            silent: false,
            vibrate: [200, 100, 200, 100, 200],
            data: {
              senderId: senderId,
              messageType: messageData.messageType || 'text',
              chatId: chatId,
              messageId: context.params.messageId,
            },
            actions: [
              {
                action: 'open',
                title: 'Open Chat'
              }
            ],
            // Mobile-specific enhancements
            dir: 'auto',
            lang: 'en',
            image: '/favicon.png'
          },
          fcm_options: {
            link: '/',
            analytics_label: 'chat_message'
          },
          // Enhanced headers for better mobile delivery
          headers: {
            'Urgency': 'high',
            'TTL': '86400' // 24 hours
          }
        },
      };

      // Send the message using FCM v1 API
      const response = await admin.messaging().send(message);
      console.log('Successfully sent message:', response);
      
      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      return null;
    }
  });

// Update FCM token when user signs in
exports.updateFcmToken = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { fcmToken } = data;
  const userId = context.auth.uid;

  if (!fcmToken) {
    throw new functions.https.HttpsError('invalid-argument', 'FCM token is required');
  }

  try {
    await admin.firestore().collection('users').doc(userId).update({
      fcmToken: fcmToken,
      lastTokenUpdate: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error('Error updating FCM token:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update FCM token');
  }
});

// Timeline fan-out: Copy posts to followers' timelines when someone posts
exports.fanOutPostToFollowers = functions.firestore
  .document('posts/{postId}')
  .onCreate(async (snapshot, context) => {
    const postData = snapshot.data();
    if (!postData) {
      console.log('No post data found');
      return null;
    }

    const authorId = postData.userId;
    const postId = context.params.postId;

    if (!authorId) {
      console.log('No author ID found in post');
      return null;
    }

    try {
      console.log(`Fanning out post ${postId} from user ${authorId} to followers`);

      // Get all followers of the author
      const followersRef = admin.firestore()
        .collection('users')
        .doc(authorId)
        .collection('followers');
      
      const followersSnap = await followersRef.get();

      if (followersSnap.empty) {
        console.log(`No followers found for user ${authorId}`);
        return null;
      }

      console.log(`Found ${followersSnap.size} followers for user ${authorId}`);

      // Prepare the post data for timeline (with author info)
      const timelinePostData = {
        ...postData,
        authorUsername: postData.authorUsername || '',
        authorPhotoUrl: postData.authorPhotoUrl || '',
        timestamp: postData.timestamp || admin.firestore.FieldValue.serverTimestamp(),
      };

      // Use batched writes for better performance
      const batchArray = [];
      let batch = admin.firestore().batch();
      let opCount = 0;

      followersSnap.forEach((doc) => {
        const followerId = doc.id;

        const timelineRef = admin.firestore()
          .collection('users')
          .doc(followerId)
          .collection('timeline')
          .doc(postId);

        batch.set(timelineRef, timelinePostData);
        opCount++;

        // Firestore batch limit = 500 writes
        if (opCount === 500) {
          batchArray.push(batch);
          batch = admin.firestore().batch();
          opCount = 0;
        }
      });

      // Add the last batch if it has operations
      if (opCount > 0) {
        batchArray.push(batch);
      }

      // Commit all batches sequentially
      console.log(`Committing ${batchArray.length} batches for timeline fan-out`);
      for (const b of batchArray) {
        await b.commit();
      }

      console.log(`Successfully fanned out post ${postId} to ${followersSnap.size} followers`);
      return null;
    } catch (error) {
      console.error('Error fanning out post to followers:', error);
      throw error;
    }
  });

// Also fan out photos to followers' timelines
exports.fanOutPhotoToFollowers = functions.firestore
  .document('photos/{photoId}')
  .onCreate(async (snapshot, context) => {
    const photoData = snapshot.data();
    if (!photoData) {
      console.log('No photo data found');
      return null;
    }

    const authorId = photoData.userId;
    const photoId = context.params.photoId;

    if (!authorId) {
      console.log('No author ID found in photo');
      return null;
    }

    try {
      console.log(`Fanning out photo ${photoId} from user ${authorId} to followers`);

      // Get all followers of the author
      const followersRef = admin.firestore()
        .collection('users')
        .doc(authorId)
        .collection('followers');
      
      const followersSnap = await followersRef.get();

      if (followersSnap.empty) {
        console.log(`No followers found for user ${authorId}`);
        return null;
      }

      console.log(`Found ${followersSnap.size} followers for user ${authorId}`);

      // Prepare the photo data for timeline
      const timelinePhotoData = {
        ...photoData,
        authorUsername: photoData.authorUsername || '',
        authorPhotoUrl: photoData.authorPhotoUrl || '',
        timestamp: photoData.timestamp || admin.firestore.FieldValue.serverTimestamp(),
      };

      // Use batched writes for better performance
      const batchArray = [];
      let batch = admin.firestore().batch();
      let opCount = 0;

      followersSnap.forEach((doc) => {
        const followerId = doc.id;

        const timelineRef = admin.firestore()
          .collection('users')
          .doc(followerId)
          .collection('timeline')
          .doc(photoId);

        batch.set(timelineRef, timelinePhotoData);
        opCount++;

        // Firestore batch limit = 500 writes
        if (opCount === 500) {
          batchArray.push(batch);
          batch = admin.firestore().batch();
          opCount = 0;
        }
      });

      // Add the last batch if it has operations
      if (opCount > 0) {
        batchArray.push(batch);
      }

      // Commit all batches sequentially
      console.log(`Committing ${batchArray.length} batches for photo timeline fan-out`);
      for (const b of batchArray) {
        await b.commit();
      }

      console.log(`Successfully fanned out photo ${photoId} to ${followersSnap.size} followers`);
      return null;
    } catch (error) {
      console.error('Error fanning out photo to followers:', error);
      throw error;
    }
  }); 