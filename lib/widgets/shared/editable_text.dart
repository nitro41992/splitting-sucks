import 'package:flutter/material.dart';

class EditableText extends StatelessWidget {
  final String text;
  final ValueChanged<String> onChanged;
  final TextStyle? style;
  final String dialogTitle;
  final String labelText;
  final String hintText;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  const EditableText({
    super.key,
    required this.text,
    required this.onChanged,
    this.style,
    this.dialogTitle = 'Edit Text',
    this.labelText = 'Value',
    this.hintText = 'Enter value',
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _showEditDialog(context),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Ensure Row doesn't expand unnecessarily
        children: [
          Flexible( // Use Flexible to allow text to wrap or truncate
            child: Text(
              text,
              style: style ?? Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis, // Prevent overflow issues
            ),
          ),
          const SizedBox(width: 4), // Add some spacing
          Icon(
            Icons.edit_outlined,
            size: (style?.fontSize ?? Theme.of(context).textTheme.titleMedium?.fontSize ?? 16) * 0.8,
            color: colorScheme.primary.withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: text);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(dialogTitle),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          style: textTheme.bodyLarge,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onChanged(controller.text.trim());
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
} 