import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'user/startupscreen.dart';
// உங்கள் firebase_options.dart கோப்பை இங்கே இறக்குமதி செய்யவும்
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase-ஐத் தொடங்குதல் (flutterfire configure செய்த பிறகு options-ஐ மாற்றவும்)
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Flutter App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const StartupScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
