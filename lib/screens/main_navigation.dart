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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 10,
              offset: Offset(0, -1),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), // Modern filled icon
              activeIcon: Icon(
                Icons.receipt_long_rounded,
                size: 26, // Slightly larger when active
              ),
              label: 'Receipts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded), // Modern filled icon
              activeIcon: Icon(
                Icons.settings_rounded,
                size: 26, // Slightly larger when active
              ),
              label: 'Settings',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF5D737E), // Slate blue for text
          unselectedItemColor: const Color(0xFF8A8A8E), // Secondary text color
          backgroundColor: Colors.white,
          elevation: 8,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          type: BottomNavigationBarType.fixed,
          selectedIconTheme: const IconThemeData(
            color: Color(0xFF5D737E), // Ensure slate blue for active icon
            size: 26, 
          ),
          unselectedIconTheme: const IconThemeData(
            color: Color(0xFF8A8A8E), // Secondary color for inactive icons
            size: 24,
          ),
          onTap: _onItemTapped,
        ),
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
        backgroundColor: Colors.white,
        elevation: 1,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'logo.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Billfie',
              style: TextStyle(
                color: Color(0xFF1D1D1F), // Primary text color
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Smarter bill splitting',
              style: TextStyle(
                color: const Color(0xFF8A8A8E), // Secondary text color
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
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
      backgroundColor: const Color(0xFFF5F5F7), // Very light grey background
    );
  }
} 