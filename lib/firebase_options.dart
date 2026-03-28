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

  // Configuración de Firebase para Web/Windows.
  // IMPORTANTE: Para producción, obtén el config real desde Firebase Console:
  // 1. Ve a Firebase Console → Project Settings → General
  // 2. Baja hasta "Your apps" y selecciona la app Web
  // 3. Copia el firebaseConfig y reemplaza los valores abajo
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
    appId: '1:118597085547:web:fluter_apk',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
    authDomain: 'sistema-integrado-sindicato.firebaseapp.com',
  );

  // iOS usa la misma configuración que Android (mismo proyecto Firebase)
  // Para producción, registra la app iOS en Firebase Console y usa GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
    appId: '1:118597085547:ios:fluter_apk',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
  );

  // Windows usa la configuración de Web (Firebase trata Windows como Web)
  // Asegúrate de tener habilitada la autenticación en Firebase Console
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
    appId: '1:118597085547:web:fluter_apk',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
    authDomain: 'sistema-integrado-sindicato.firebaseapp.com',
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
