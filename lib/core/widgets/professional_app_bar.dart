import 'package:flutter/material.dart';

class ProfessionalAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ProfessionalAppBar({
    super.key,
    required this.title,
    this.onNavigateBack,
    this.actions,
  });

  final String title;
  final VoidCallback? onNavigateBack;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: onNavigateBack != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onNavigateBack,
            )
          : null,
      actions: actions,
    );
  }
}
