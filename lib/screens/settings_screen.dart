import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  
  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _authService.signOut();
      // Navigation will be handled by the auth state listener in the app
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Account Deletion'),
        content: const Text(
          'Are you sure you want to permanently delete your account?\n\n'
          'This will:\n'
          '- Delete all your receipt history\n'
          '- Remove all your saved data\n'
          '- Permanently delete your account',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Placeholder for account deletion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion will be implemented in a future update'),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Account section
                const ListTile(
                  title: Text(
                    'Account',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  subtitle: Text(
                    FirebaseAuth.instance.currentUser?.email ?? 'Not signed in',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile management will be implemented in a future update'),
                      ),
                    );
                  },
                ),
                
                const Divider(),
                
                // App preferences section
                const ListTile(
                  title: Text(
                    'App Preferences',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                ListTile(
                  leading: const Icon(Icons.color_lens),
                  title: const Text('Appearance'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Appearance settings will be implemented in a future update'),
                      ),
                    );
                  },
                ),
                
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification settings will be implemented in a future update'),
                      ),
                    );
                  },
                ),
                
                const Divider(),
                
                // About section
                const ListTile(
                  title: Text(
                    'About',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text('App Info'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Billfie',
                      applicationVersion: '1.0.1',
                      applicationLegalese: '© 2024 Billfie',
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text('A smart receipt splitting app that makes splitting bills easier.'),
                        ),
                      ],
                    );
                  },
                ),
                
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help & support will be implemented in a future update'),
                      ),
                    );
                  },
                ),
                
                const Divider(),
                
                // Account actions section
                const ListTile(
                  title: Text(
                    'Account Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log Out'),
                  onTap: _logout,
                ),
                
                ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red.shade700),
                  title: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red.shade700,
                    ),
                  ),
                  onTap: _deleteAccount,
                ),
              ],
            ),
    );
  }
} 