// Configuración de Firebase para el proyecto sistema-integrado-sindicato.
// Generada a partir de google-services.json (la CLI falló con "UnsupportedError" al escribir).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
    appId: '1:118597085547:android:5f4119dd6934a00329c42e',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
  );

  // Web/iOS/Windows: mismo proyecto; si falla en alguna plataforma, copia
  // el config de esa app desde Firebase Console → Configuración del proyecto.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
    appId: '1:118597085547:web:fluter_apk',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
    appId: '1:118597085547:ios:fluter_apk',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
    appId: '1:118597085547:web:fluter_apk_windows',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return web;
      default:
        return android;
    }
  }
}
