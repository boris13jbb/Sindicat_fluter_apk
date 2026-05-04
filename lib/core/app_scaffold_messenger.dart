import 'package:flutter/material.dart';

/// Clave global para mostrar SnackBars desde servicios/providers sin [BuildContext].
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
