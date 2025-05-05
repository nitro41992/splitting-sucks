import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/receipts_screen.dart';
import 'screens/settings_screen.dart';
import 'services/receipt_service.dart';
import 'models/receipt.dart';
import 'widgets/receipt_workflow_page.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _currentIndex = 0;
  final ReceiptService _receiptService = ReceiptService();
  bool _hasSetupListeners = false;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // If not logged in, show login screen
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }
        
        // Set up listeners once (if needed)
        if (!_hasSetupListeners) {
          _hasSetupListeners = true;
        }
        
        // Show main app UI
        return Scaffold(
          body: _buildBody(),
          bottomNavigationBar: _buildBottomNavBar(),
          floatingActionButton: _currentIndex == 0 ? FloatingActionButton(
            onPressed: _startNewReceipt,
            heroTag: 'add_receipt_button',
            child: const Icon(Icons.add),
          ) : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }
  
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return ReceiptsScreen(
          onReceiptTap: _openReceiptWorkflow,
          onAddReceiptTap: _startNewReceipt,
        );
      case 1:
        return SettingsScreen();
      default:
        return const Center(child: Text('Page not found'));
    }
  }
  
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Receipts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
  
  Future<void> _startNewReceipt() async {
    try {
      // Create a new receipt draft
      final receipt = await _receiptService.createReceiptDraft();
      
      if (!mounted) return;
      
      // Open receipt workflow with the new draft
      _openReceiptWorkflow(receipt);
    } catch (e) {
      debugPrint('Error creating receipt draft: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating receipt: $e')),
      );
    }
  }
  
  void _openReceiptWorkflow(Receipt receipt) {
    // Replace modal with full page navigation
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReceiptWorkflowPage(receipt: receipt),
      ),
    ).then((_) {
      // Refresh the receipts list when workflow is closed
      setState(() {});
    });
  }
} 