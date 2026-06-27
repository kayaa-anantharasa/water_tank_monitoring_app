import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'adminlogin.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isAdmin;
  final Function(bool) onLoginStateChanged;

  const CustomAppBar({
    super.key,
    required this.title,
    required this.isAdmin,
    required this.onLoginStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      elevation: 2,
      actions: [
        // Dynamic Indicator: Shows Admin (Green) or Guest (Grey)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              isAdmin ? 'Admin' : 'Guest',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isAdmin ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ),

        // Profile Icon with Dynamic Dropdown Menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle, size: 30),
          tooltip: 'Profile Options',
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (String result) async {
            if (result == 'admin_login') {
              // Wait for the dialog to return a result (true if login succeeds)
              final bool? loginSuccess = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const AdminLoginDialog();
                },
              );

              // If Firebase login was successful, update the app state
              if (loginSuccess == true) {
                onLoginStateChanged(true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged in as Admin'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else if (result == 'logout') {
              // Handle Firebase Logout
              await FirebaseAuth.instance.signOut();
              onLoginStateChanged(false); // Switch back to Guest Mode
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Logged out successfully. Switched to Guest Mode.',
                  ),
                  backgroundColor: Colors.grey,
                ),
              );
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            // Show this ONLY if the user is a Guest
            if (!isAdmin)
              const PopupMenuItem<String>(
                value: 'admin_login',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.blueAccent),
                    SizedBox(width: 12),
                    Text(
                      'Admin Sign-in',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            // Show this ONLY if the user is an Admin
            if (isAdmin)
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(width: 10), // Right edge padding
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
