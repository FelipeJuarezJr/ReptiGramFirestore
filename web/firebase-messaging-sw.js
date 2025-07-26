// Firebase messaging service worker for web push notifications
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js');

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

// Detect if running on mobile
const isMobile = /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('📨 Received background message:', payload);
  console.log('📱 Mobile device:', isMobile);

  const notificationTitle = payload.notification?.title || 'New Message';
  const notificationBody = payload.notification?.body || 'You have a new message';
  
  // Enhanced notification options for mobile
  const notificationOptions = {
    body: notificationBody,
    icon: '/favicon.png',
    badge: '/favicon.png',
    data: payload.data || {},
    actions: [
      {
        action: 'open',
        title: 'Open Chat'
      }
    ],
    requireInteraction: true,
    tag: 'chat-message',
    renotify: true,
    silent: false,
    vibrate: isMobile ? [200, 100, 200, 100, 200] : [200, 100, 200],
    // Mobile-specific enhancements
    ...(isMobile && {
      sound: 'default',
      priority: 'high',
      dir: 'auto',
      lang: 'en'
    })
  };

  console.log('🔔 Showing notification with mobile enhancements:', notificationOptions);

  return self.registration.showNotification(notificationTitle, notificationOptions)
    .then(() => {
      console.log('✅ Background notification shown successfully');
      
      // For mobile devices, try to wake up the device
      if (isMobile) {
        console.log('📱 Attempting to wake up mobile device...');
        // Play a silent audio to help wake up the device
        try {
          const audioContext = new (self.AudioContext || self.webkitAudioContext)();
          const oscillator = audioContext.createOscillator();
          const gainNode = audioContext.createGain();
          
          oscillator.connect(gainNode);
          gainNode.connect(audioContext.destination);
          
          // Set volume to 0 (silent) but still triggers audio context
          gainNode.gain.setValueAtTime(0, audioContext.currentTime);
          
          oscillator.frequency.setValueAtTime(440, audioContext.currentTime);
          oscillator.start();
          oscillator.stop(audioContext.currentTime + 0.1);
          
          console.log('🔊 Silent audio played to wake up device');
        } catch (error) {
          console.log('⚠️ Could not play silent audio:', error);
        }
      }
    })
    .catch((error) => {
      console.error('❌ Error showing background notification:', error);
    });
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('👆 Notification clicked:', event);

  event.notification.close();

  if (event.action === 'open' || !event.action) {
    event.waitUntil(
      clients.openWindow('/')
        .then((windowClient) => {
          console.log('✅ App opened from notification');
          return windowClient;
        })
        .catch((error) => {
          console.error('❌ Error opening app from notification:', error);
        })
    );
  }
});

// Handle service worker installation
self.addEventListener('install', (event) => {
  console.log('🔧 Service worker installing...');
  self.skipWaiting();
});

// Handle service worker activation
self.addEventListener('activate', (event) => {
  console.log('✅ Service worker activating...');
  event.waitUntil(self.clients.claim());
});

// Handle push events (fallback)
self.addEventListener('push', (event) => {
  console.log('📨 Push event received:', event);
  console.log('📱 Mobile device:', isMobile);
  
  if (event.data) {
    try {
      const payload = event.data.json();
      console.log('📦 Push payload:', payload);
      
      const notificationTitle = payload.notification?.title || 'New Message';
      const notificationBody = payload.notification?.body || 'You have a new message';
      
      const notificationOptions = {
        body: notificationBody,
        icon: '/favicon.png',
        badge: '/favicon.png',
        data: payload.data || {},
        requireInteraction: true,
        tag: 'chat-message',
        renotify: true,
        silent: false,
        vibrate: isMobile ? [200, 100, 200, 100, 200] : [200, 100, 200],
        // Mobile-specific enhancements
        ...(isMobile && {
          sound: 'default',
          priority: 'high',
          dir: 'auto',
          lang: 'en'
        })
      };

      console.log('🔔 Showing push notification with mobile enhancements:', notificationOptions);

      event.waitUntil(
        self.registration.showNotification(notificationTitle, notificationOptions)
          .then(() => {
            console.log('✅ Push notification shown successfully');
            
            // For mobile devices, try to wake up the device
            if (isMobile) {
              console.log('📱 Attempting to wake up mobile device from push...');
              try {
                // Try to request wake lock if supported
                if ('wakeLock' in navigator) {
                  navigator.wakeLock.request('screen').then(lock => {
                    console.log('🔒 Wake lock acquired');
                    // Release wake lock after a short time
                    setTimeout(() => {
                      lock.release();
                      console.log('🔓 Wake lock released');
                    }, 5000);
                  }).catch(error => {
                    console.log('⚠️ Could not acquire wake lock:', error);
                  });
                }
              } catch (error) {
                console.log('⚠️ Wake lock not supported:', error);
              }
            }
          })
          .catch((error) => {
            console.error('❌ Error showing push notification:', error);
          })
      );
    } catch (error) {
      console.error('❌ Error parsing push payload:', error);
    }
  } else {
    console.log('⚠️ Push event received but no data');
  }
});

// Handle service worker message events
self.addEventListener('message', (event) => {
  console.log('📨 Service worker received message:', event.data);
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
  
  // Handle keep-alive messages
  if (event.data && event.data.type === 'KEEP_ALIVE') {
    console.log('💓 Keep-alive message received');
  }
  
  // Handle ping messages
  if (event.data && event.data.type === 'PING') {
    console.log('🏓 Ping message received');
  }
});

// Periodic wake-up for mobile devices (every 10 minutes)
if (isMobile) {
  setInterval(() => {
    console.log('⏰ Periodic wake-up check for mobile device');
    // Send a message to keep the service worker active
    self.clients.matchAll().then(clients => {
      clients.forEach(client => {
        client.postMessage({
          type: 'PERIODIC_WAKE_UP',
          timestamp: Date.now()
        });
      });
    });
  }, 10 * 60 * 1000); // 10 minutes
} 