// Configuración de Firebase para el proyecto sistema-integrado-sindicato.
// Generada a partir de google-services.json (la CLI falló con "UnsupportedError" al escribir).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAmgUtQ8T7VuIlJFO5RKC3cgdSCaQzPaDA',
    appId: '1:118597085547:android:5f4119dd6934a00329c42e',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    databaseURL:
        'https://sistema-integrado-sindicato-default-rtdb.firebaseio.com',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
  );

  // Configuración de Firebase para Web/Windows.
  // IMPORTANTE: Para producción, obtén el config real desde Firebase Console:
  // 1. Ve a Firebase Console → Project Settings → General
  // 2. Baja hasta "Your apps" y selecciona la app Web

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDiKl-oJ4joC1baziADpZrEE_VBsIswmnw',
    appId: '1:118597085547:web:e271a8df15ab863829c42e',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    authDomain: 'sistema-integrado-sindicato.firebaseapp.com',
    databaseURL:
        'https://sistema-integrado-sindicato-default-rtdb.firebaseio.com',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
    measurementId: 'G-7MB779713S',
  );

  // 3. Copia el firebaseConfig y reemplaza los valores abajo

  // iOS usa la misma configuración que Android (mismo proyecto Firebase)

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCHIx1Eptaxn0oqoOnzMa3GlONfLtCCCDM',
    appId: '1:118597085547:ios:09c54b87dd6fe63c29c42e',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    databaseURL:
        'https://sistema-integrado-sindicato-default-rtdb.firebaseio.com',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
    androidClientId:
        '118597085547-p5dh4q92rqp86568v5fivtaqs271rgbt.apps.googleusercontent.com',
    iosClientId:
        '118597085547-9sj43sm2nnnusih3v95hbihi2qsmtbn2.apps.googleusercontent.com',
    iosBundleId: 'com.sindicato.votos.fluterApk',
  );

  // Para producción, registra la app iOS en Firebase Console y usa GoogleService-Info.plist

  // Windows usa la configuración de Web (Firebase trata Windows como Web)

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDiKl-oJ4joC1baziADpZrEE_VBsIswmnw',
    appId: '1:118597085547:web:f2fc7a391a15f33429c42e',
    messagingSenderId: '118597085547',
    projectId: 'sistema-integrado-sindicato',
    authDomain: 'sistema-integrado-sindicato.firebaseapp.com',
    databaseURL:
        'https://sistema-integrado-sindicato-default-rtdb.firebaseio.com',
    storageBucket: 'sistema-integrado-sindicato.firebasestorage.app',
    measurementId: 'G-3GY04B28HJ',
  );

  // Asegúrate de tener habilitada la autenticación en Firebase Console

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
