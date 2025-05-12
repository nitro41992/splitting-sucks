import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper function to build dialog widgets for testing
  Widget buildDialogTestWidget({
    required Widget child,
  }) {
    return MaterialApp(
      home: Material(
        child: Builder(
          builder: (BuildContext context) {
            // We use a Builder to get the correct context
            return ElevatedButton(
              onPressed: () {
                // Show the dialog using the correct context
                showDialog(
                  context: context,
                  builder: (_) => child,
                );
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ),
    );
  }

  group('Confirmation Dialog Tests', () {
    testWidgets('renders confirmation dialog with correct title and message', (WidgetTester tester) async {
      // Replace this with the actual dialog widget from your app
      final dialog = AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Confirm'),
          ),
        ],
      );
      
      await tester.pumpWidget(buildDialogTestWidget(child: dialog));
      
      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Verify dialog content
      expect(find.text('Confirmation'), findsOneWidget);
      expect(find.text('Are you sure you want to proceed?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('calls onCancel when Cancel button is pressed', (WidgetTester tester) async {
      bool cancelPressed = false;
      bool confirmPressed = false;
      
      // Replace this with the actual dialog widget from your app
      final dialog = AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () {
              cancelPressed = true;
              Navigator.of(tester.element(find.text('Cancel'))).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              confirmPressed = true;
              Navigator.of(tester.element(find.text('Confirm'))).pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      );
      
      await tester.pumpWidget(buildDialogTestWidget(child: dialog));
      
      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Tap the Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      
      // Verify onCancel was called
      expect(cancelPressed, isTrue);
      expect(confirmPressed, isFalse);
      
      // Verify dialog is dismissed
      expect(find.text('Confirmation'), findsNothing);
    });

    testWidgets('calls onConfirm when Confirm button is pressed', (WidgetTester tester) async {
      bool cancelPressed = false;
      bool confirmPressed = false;
      
      // Replace this with the actual dialog widget from your app
      final dialog = AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Are you sure you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () {
              cancelPressed = true;
              Navigator.of(tester.element(find.text('Cancel'))).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              confirmPressed = true;
              Navigator.of(tester.element(find.text('Confirm'))).pop();
            },
            child: const Text('Confirm'),
          ),
        ],
      );
      
      await tester.pumpWidget(buildDialogTestWidget(child: dialog));
      
      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Tap the Confirm button
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      
      // Verify onConfirm was called
      expect(confirmPressed, isTrue);
      expect(cancelPressed, isFalse);
      
      // Verify dialog is dismissed
      expect(find.text('Confirmation'), findsNothing);
    });
  });

  group('Error Dialog Tests', () {
    testWidgets('renders error dialog with correct title and message', (WidgetTester tester) async {
      // Replace this with the actual error dialog widget from your app
      final dialog = AlertDialog(
        title: const Text('Error'),
        content: const Text('Something went wrong. Please try again.'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('OK'),
          ),
        ],
      );
      
      await tester.pumpWidget(buildDialogTestWidget(child: dialog));
      
      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Verify dialog content
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('dismisses error dialog when OK button is pressed', (WidgetTester tester) async {
      bool okPressed = false;
      
      // Replace this with the actual error dialog widget from your app
      final dialog = AlertDialog(
        title: const Text('Error'),
        content: const Text('Something went wrong. Please try again.'),
        actions: [
          TextButton(
            onPressed: () {
              okPressed = true;
              Navigator.of(tester.element(find.text('OK'))).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
      
      await tester.pumpWidget(buildDialogTestWidget(child: dialog));
      
      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Tap the OK button
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      
      // Verify OK button press was handled
      expect(okPressed, isTrue);
      
      // Verify dialog is dismissed
      expect(find.text('Error'), findsNothing);
    });
  });

  group('Loading Dialog Tests', () {
    testWidgets('renders loading dialog with spinner and message', (WidgetTester tester) async {
      // Replace this with the actual loading dialog widget from your app
      final dialog = AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            const Text('Loading...'),
          ],
        ),
      );
      
      await tester.pumpWidget(buildDialogTestWidget(child: dialog));
      
      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Verify dialog content
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('loading dialog is properly dismissed when task completes', (WidgetTester tester) async {
      // Create a dialog that automatically dismisses after a delay
      final dialog = FutureBuilder<bool>(
        future: Future.delayed(const Duration(milliseconds: 100), () => true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Automatically dismiss the dialog when done
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pop();
            });
            return const SizedBox(); // Return empty widget when done
          }
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Loading...'),
              ],
            ),
          );
        },
      );
      
      await tester.pumpWidget(buildDialogTestWidget(child: dialog));
      
      // Tap the button to show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Initially, spinner and loading text should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
      
      // Wait for the future to complete and dialog to dismiss
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      
      // Verify dialog is dismissed
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Loading...'), findsNothing);
    });
  });
} 