import 'package:flutter/material.dart';

import '../app_design_tokens.dart';

/// Campo de búsqueda con estilo premium (borde suave, forma píldora opcional).
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.pillShape = true,
    this.readOnly = false,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final bool pillShape;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = pillShape ? 999.0 : AppDesignTokens.radiusMedium;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, color: AppDesignTokens.primary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppDesignTokens.primary, width: 1.5),
        ),
      ),
    );
  }
}
