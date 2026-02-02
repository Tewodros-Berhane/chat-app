// GENERATED FILE PLACEHOLDER.
// Run `flutterfire configure` to generate real Firebase options.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

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
        return linux;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA3CeUjA95t2a5xpN8_KOsWod5oOYXMfG4',
    appId: '1:674892935030:web:b304837859da476e1a9457',
    messagingSenderId: '674892935030',
    projectId: 'chat-app-990-81836',
    authDomain: 'chat-app-990-81836.firebaseapp.com',
    storageBucket: 'chat-app-990-81836.firebasestorage.app',
    measurementId: 'G-Y6N60H86SD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyALaTjes11Bi_1PzM0rQXwK8UfV-I0gy-Q',
    appId: '1:674892935030:android:ca61cb5f15c3e8e01a9457',
    messagingSenderId: '674892935030',
    projectId: 'chat-app-990-81836',
    storageBucket: 'chat-app-990-81836.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDvOjQkPJCYyJkQpZnky-QE20JgzcxcVSw',
    appId: '1:674892935030:ios:701627dfa8bb3fdc1a9457',
    messagingSenderId: '674892935030',
    projectId: 'chat-app-990-81836',
    storageBucket: 'chat-app-990-81836.firebasestorage.app',
    iosBundleId: 'com.example.chatApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.chatApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA3CeUjA95t2a5xpN8_KOsWod5oOYXMfG4',
    appId: '1:674892935030:web:c9b25559aeedd4d91a9457',
    messagingSenderId: '674892935030',
    projectId: 'chat-app-990-81836',
    authDomain: 'chat-app-990-81836.firebaseapp.com',
    storageBucket: 'chat-app-990-81836.firebasestorage.app',
    measurementId: 'G-GFMZ8TBPWT',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}