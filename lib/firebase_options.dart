import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase project.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ⚠️ 重要：請將以下設定替換為你的 Firebase 專案設定
  // 你可以在 Firebase Console > 專案設定 > 一般 > 你的應用程式 中找到這些值

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC-rY3GqE3jAS6PUOfxqg5KNfmMv9hRB1Q',
    appId: '1:320201170891:web:cf8b719942d1382936204e',
    messagingSenderId: '320201170891',
    projectId: 'foodmngmt-a8c19',
    authDomain: 'foodmngmt-a8c19.firebaseapp.com',
    storageBucket: 'foodmngmt-a8c19.firebasestorage.app',
    measurementId: 'G-485WPW9V94',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB5MvTMhfRu-CXTuQmi05NSDb2zLjZKSYo',
    appId: '1:320201170891:android:8c768a27964b726b36204e',
    messagingSenderId: '320201170891',
    projectId: 'foodmngmt-a8c19',
    storageBucket: 'foodmngmt-a8c19.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBBRZhusdLaxbz8QGcIT-FDQxoSt7DIVwY',
    appId: '1:320201170891:ios:05a1121986d3f74436204e',
    messagingSenderId: '320201170891',
    projectId: 'foodmngmt-a8c19',
    storageBucket: 'foodmngmt-a8c19.firebasestorage.app',
    iosBundleId: 'com.example.foodmngmt',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBBRZhusdLaxbz8QGcIT-FDQxoSt7DIVwY',
    appId: '1:320201170891:ios:05a1121986d3f74436204e',
    messagingSenderId: '320201170891',
    projectId: 'foodmngmt-a8c19',
    storageBucket: 'foodmngmt-a8c19.firebasestorage.app',
    iosBundleId: 'com.example.foodmngmt',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC-rY3GqE3jAS6PUOfxqg5KNfmMv9hRB1Q',
    appId: '1:320201170891:web:f0ca66c0d1160c1a36204e',
    messagingSenderId: '320201170891',
    projectId: 'foodmngmt-a8c19',
    authDomain: 'foodmngmt-a8c19.firebaseapp.com',
    storageBucket: 'foodmngmt-a8c19.firebasestorage.app',
    measurementId: 'G-DS03LREMFK',
  );

}