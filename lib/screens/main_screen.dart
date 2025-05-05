import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import 'create_workflow_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // List of screens to display
  final List<Widget> _screens = [
    const CreateWorkflowScreen(),
    const HistoryScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Check if the device is running iOS
    final bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    
    return Scaffold(
      body: SafeArea(
        // Add bottom padding for iOS devices with home indicator
        bottom: isIOS, 
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: isIOS
          ? _buildCupertinoTabBar() // iOS-specific tab bar
          : _buildMaterialBottomNavBar(), // Android-specific bottom nav bar
    );
  }
  
  // Material Design bottom navigation bar (Android style)
  Widget _buildMaterialBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          activeIcon: Icon(Icons.add_circle),
          label: 'Create',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          activeIcon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
  
  // Cupertino tab bar (iOS style)
  Widget _buildCupertinoTabBar() {
    return CupertinoTabBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.add_circled),
          activeIcon: Icon(CupertinoIcons.add_circled_solid),
          label: 'Create',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.clock),
          activeIcon: Icon(CupertinoIcons.clock_fill),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.settings),
          activeIcon: Icon(CupertinoIcons.settings_solid),
          label: 'Settings',
        ),
      ],
    );
  }
} 