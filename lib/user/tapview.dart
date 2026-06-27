import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'appbar.dart';
import 'Home.dart';
import 'History.dart';
import 'alerts.dart';
import 'more.dart';

class TapView extends StatefulWidget {
  const TapView({super.key});

  @override
  State<TapView> createState() => _TapViewState();
}

class _TapViewState extends State<TapView> {
  int _currentIndex = 0;
  bool _isAdmin = false; // Central state for the entire app

  @override
  void initState() {
    super.initState();
    // Check if the user is already logged in when the app starts
    if (FirebaseAuth.instance.currentUser != null) {
      _isAdmin = true;
    }
  }

  // Titles to display in the AppBar
  final List<String> _titles = const ['Home', 'History', 'Alerts', 'More'];

  @override
  Widget build(BuildContext context) {
    // We build the screens list inside the build method so that
    // MoreScreen and AlertsScreen always get the latest _isAdmin value.
    final List<Widget> screens = [
      const HomeScreen(),
      const HistoryScreen(),
      AlertsScreen(
        isAdmin: _isAdmin,
      ), // <-- FIXED: Added isAdmin and removed const
      MoreScreen(
        isAdmin: _isAdmin,
        onLoginStateChanged: (bool status) {
          setState(() {
            _isAdmin = status;
          });
        },
      ), // Passes admin state to lock/unlock Pump Control
    ];

    return Scaffold(
      appBar: CustomAppBar(
        title: _titles[_currentIndex],
        isAdmin: _isAdmin,
        onLoginStateChanged: (bool status) {
          // This updates the UI globally when the user logs in or logs out
          setState(() {
            _isAdmin = status;
          });
        },
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
