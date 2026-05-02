import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Insets del sistema (**gestual / 3 botones / indicador hogar**) que a veces
/// solo llegan por [MediaQuery.viewPadding]; las unimos con [MediaQuery.padding]
/// para que [Scaffold] y el FAB reserven espacio inferior/lateral sin tapar contenido.
///
/// Ver también: [SafeArea], [MediaQuery.viewPadding].
MediaQueryData mediaQueryWithSystemGestureInsets(BuildContext context) {
  final mq = MediaQuery.of(context);
  final p = mq.padding;
  final v = mq.viewPadding;
  return mq.copyWith(
    padding: p.copyWith(
      left: math.max(p.left, v.left),
      right: math.max(p.right, v.right),
      bottom: math.max(p.bottom, v.bottom),
    ),
  );
}
