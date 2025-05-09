import 'package:flutter/material.dart';

/// Dialog to prompt for restaurant name
Future<String?> showRestaurantNameDialog(BuildContext context, {String? initialName}) async {
  // Add mounted check before attempting to show a dialog
  if (!context.mounted) {
    debugPrint("[showRestaurantNameDialog] Error: Context is not mounted before showing dialog.");
    return null;
  }
  final TextEditingController controller = TextEditingController(text: initialName);

  return showDialog<String>(
    context: context,
    barrierDismissible: false, // User must respond to dialog
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Restaurant Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the name of the restaurant or store:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Restaurant Name',
                hintText: 'e.g., Joe\'s Diner',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null), // Cancel
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) {
                // Show error if empty
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Restaurant name is required'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else {
                Navigator.of(context).pop(name);
              }
            },
            child: const Text('CONTINUE'),
          ),
        ],
      );
    },
  );
}

/// Helper for confirmation dialog
Future<bool> showConfirmationDialog(BuildContext context, String title, String content) async {
  if (!context.mounted) return false;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false), // Cancel
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true), // Confirm
          child: const Text('CONFIRM'),
        ),
      ],
    ),
  );
  return result ?? false;
} 