import 'package:flutter/material.dart';
import 'receipts_screen.dart';
import '../services/auth_service.dart';
import '../utils/toast_helper.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  // Define pages directly if they are simple, or keep them in a list
  // if they need more complex instantiation or keys.
  // For IndexedStack, it's common to build them directly in the stack.
  // final List<Widget> _screens = [
  //   const ReceiptsScreen(), 
  //   const SettingsScreen(),
  // ];
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // body: _screens[_selectedIndex], // OLD WAY
      body: IndexedStack( // NEW WAY
        index: _selectedIndex,
        children: const <Widget>[
          ReceiptsScreen(), // Instantiate here
          SettingsScreen(), // Instantiate here
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Receipts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

/// Placeholder for Settings screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Account'),
            onTap: () {
              // TODO: Implement account settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('CANCEL'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('SIGN OUT'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                try {
                  await AuthService().signOut();
                  // Navigation to LoginScreen should be handled by StreamBuilder in main.dart
                  ToastHelper.showToast(context, 'Successfully signed out', isSuccess: true);
                } catch (e) {
                  ToastHelper.showToast(context, 'Error signing out: $e', isError: true);
                }
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              // TODO: Implement about screen
            },
          ),
        ],
      ),
    );
  }
} 