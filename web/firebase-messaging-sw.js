// Firebase messaging service worker for web push notifications
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js');

// Initialize Firebase
firebase.initializeApp({
  apiKey: "AIzaSyBevZO-43EmlnYOhTWg_xT6UcwrmVAkSsc",
  authDomain: "reptigramfirestore.firebaseapp.com",
  projectId: "reptigramfirestore",
  storageBucket: "reptigramfirestore.firebasestorage.app",
  messagingSenderId: "373955522567",
  appId: "1:373955522567:android:b4650d05f0f8b4295bbaa2",
  measurementId: "G-XHBMWC2VD6",
  databaseURL: "https://reptigramfirestore-default-rtdb.firebaseio.com"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);

  const notificationTitle = payload.notification.title || 'New Message';
  const notificationOptions = {
    body: payload.notification.body || 'You have a new message',
    icon: '/favicon.png',
    badge: '/favicon.png',
    data: payload.data || {},
    actions: [
      {
        action: 'open',
        title: 'Open Chat'
      }
    ]
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('Notification clicked:', event);

  event.notification.close();

  if (event.action === 'open' || !event.action) {
    // Open the app when notification is clicked
    event.waitUntil(
      clients.openWindow('/')
    );
  }
}); 