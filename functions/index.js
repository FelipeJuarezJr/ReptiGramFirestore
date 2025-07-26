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