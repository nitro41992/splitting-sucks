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
  int _previousIndex = 0;
  
  // Create global keys for each screen
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();
  
  // List of screens to display
  late final List<Widget> _screens;
  
  @override
  void initState() {
    super.initState();
    _screens = [
      const CreateWorkflowScreen(),
      HistoryScreen(key: _historyKey),
      const SettingsScreen(),
    ];
  }
  
  void _onTabChanged(int index) {
    // If we're switching to the History tab from another tab
    if (index == 1 && _currentIndex != 1) {
      // Schedule the refresh after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_historyKey.currentState != null) {
          _historyKey.currentState!.refreshReceipts();
        }
      });
    }
    
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

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
      onTap: _onTabChanged,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          label: 'Create',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
  
  // Cupertino tab bar (iOS style)
  Widget _buildCupertinoTabBar() {
    return CupertinoTabBar(
      currentIndex: _currentIndex,
      onTap: _onTabChanged,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.add_circled),
          label: 'Create',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.clock),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(CupertinoIcons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
} 