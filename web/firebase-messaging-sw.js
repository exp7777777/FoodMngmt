importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'YOUR API KEY',
  appId: '1:320201170891:web:cf8b719942d1382936204e',
  messagingSenderId: '320201170891',
  projectId: 'foodmngmt-a8c19',
  authDomain: 'foodmngmt-a8c19.firebaseapp.com',
  storageBucket: 'foodmngmt-a8c19.firebasestorage.app',
  measurementId: 'G-485WPW9V94',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title ?? 'FoodMngmt';
  const notificationOptions = {
    body: payload.notification?.body ?? '您有新的食材通知',
    icon: '/icons/Icon-192.png',
    data: payload.data,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

