// web/firebase-messaging-sw.js
// Required by firebase_messaging on Flutter web for background/push.
// Must be served from the app origin root (not rewritten to index.html).
// Keep config in sync with lib/config/firebase_options.dart → FirebaseOptionsConfig.web

/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAa331pMsUyRe1hsawxYUtOxPJgkby5AKU',
  authDomain: 'sitedrop-eb666.firebaseapp.com',
  projectId: 'sitedrop-eb666',
  storageBucket: 'sitedrop-eb666.appspot.com',
  messagingSenderId: '865592120613',
  appId: '1:865592120613:web:b74ecba6ee5f84cb9f36cc',
  measurementId: 'G-Z04D88MJW9',
});

// Required so FCM can take over the default messaging SW scope.
const messaging = firebase.messaging();

// Optional: handle background messages in the SW (no Flutter UI here).
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] background message', payload);
  const notification = payload.notification || {};
  const title = notification.title || 'SiteDrop';
  const options = {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});
