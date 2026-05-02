import 'dart:math' as math;

import 'package:flutter/material.dart';

class ProfessionalAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ProfessionalAppBar({
    super.key,
    required this.title,
    this.onNavigateBack,
    this.actions,
    /// Anchura máxima del bloque scrolleable para [actions]; evita tapar el título en filas muy estrechas.
    this.actionsFlexMaxFraction = 0.48,
  });

  final String title;
  final VoidCallback? onNavigateBack;

  /// Acciones derecha ([IconButton]). En pantallas estrechas con muchas ítems el bloque será desplazable horizontalmente para evitar overflow.
  final List<Widget>? actions;

  /// Fracción del ancho de pantalla destinada como tope máximo al carril de acciones cuando se activa scroll horizontal.
  final double actionsFlexMaxFraction;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenW = MediaQuery.sizeOf(context).width;

    Widget? normalizedActions;

    final rawActions = actions;
    if (rawActions != null && rawActions.isNotEmpty) {
      final needsScrollRail =
          rawActions.length > 2 && screenW < 560;
      final maxActionsW = math.max(
        screenW * actionsFlexMaxFraction,
        math.min(screenW - 140, 260.0),
      ).toDouble();

      normalizedActions = needsScrollRail
          ? SizedBox(
              width: maxActionsW,
              height: kToolbarHeight,
              child: Align(
                alignment: Alignment.centerRight,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    physics: const BouncingScrollPhysics(),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: rawActions,
                    ),
                  ),
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: rawActions,
            );
    }

    return AppBar(
      title: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: onNavigateBack != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onNavigateBack,
            )
          : null,
      actions: normalizedActions != null ? [normalizedActions] : null,
    );
  }
}
