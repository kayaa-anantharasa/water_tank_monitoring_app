import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PumpControlScreen extends StatefulWidget {
  const PumpControlScreen({super.key});

  @override
  State<PumpControlScreen> createState() => _PumpControlScreenState();
}

class _PumpControlScreenState extends State<PumpControlScreen> {
  // Updated to match your exact database structure from the screenshot
  final DatabaseReference _pumpRef = FirebaseDatabase.instance.ref().child(
    'Pump/state',
  );

  // Function to push the new state to Firebase
  Future<void> _togglePump(bool newValue) async {
    try {
      await _pumpRef.set(newValue);
    } catch (error) {
      // Show error if the database write fails (e.g., no internet)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update pump: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Pump Control'),
        backgroundColor: const Color.fromARGB(255, 82, 137, 255),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Center(
        child: StreamBuilder(
          // Listen to the database node in real-time
          stream: _pumpRef.onValue,
          builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
            // 1. Handle Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(color: Colors.redAccent);
            }

            // 2. Handle Error State
            if (snapshot.hasError) {
              return Text(
                'Connection Error.',
                style: TextStyle(
                  color: const Color.fromARGB(255, 40, 108, 198),
                  fontSize: 18,
                ),
              );
            }

            // 3. Extract the boolean value from Firebase (Default to false if null)
            bool isPumpActive = false;
            if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
              isPumpActive = snapshot.data!.snapshot.value as bool;
            }

            // 4. Build the UI based on the real-time state
            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 40.0,
                  horizontal: 60.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Icon
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isPumpActive
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPumpActive
                            ? Icons.water_drop
                            : Icons.water_drop_outlined,
                        size: 80,
                        color: isPumpActive
                            ? Colors.blue
                            : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dynamic Text
                    Text(
                      isPumpActive ? 'PUMP IS ON' : 'PUMP IS OFF',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isPumpActive
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the switch to override',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // The Toggle Switch
                    Transform.scale(
                      scale: 1.8, // Make the switch larger and easier to tap
                      child: Switch(
                        value: isPumpActive,
                        onChanged:
                            _togglePump, // Calls our function when tapped
                        activeColor: Colors.white,
                        activeTrackColor: Colors.green.shade500,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
