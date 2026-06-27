import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
// IMPORTANT: Import your appbar file here
import '../appbar.dart';

class PHStatusScreen extends StatefulWidget {
  final bool isAdmin;
  final Function(bool) onLoginStateChanged;

  const PHStatusScreen({
    super.key,
    required this.isAdmin,
    required this.onLoginStateChanged,
  });

  @override
  State<PHStatusScreen> createState() => _PHStatusScreenState();
}

class _PHStatusScreenState extends State<PHStatusScreen> {
  final DatabaseReference _rtdbRef = FirebaseDatabase.instance.ref().child(
    'SensorData',
  );
  final DocumentReference _firestoreRef = FirebaseFirestore.instance
      .collection('settings')
      .doc('ph_config');

  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  bool _isSaving = false;
  bool _isDataLoaded = false;
  late bool _localIsAdmin; // Track admin status locally for live updates

  double _currentMinPh = 6.5;
  double _currentMaxPh = 7.5;

  @override
  void initState() {
    super.initState();
    // Initialize the local state with the value passed from the parent
    _localIsAdmin = widget.isAdmin;
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _saveRangeToFirestore() async {
    if (!_localIsAdmin) {
      // Check against the local state
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Denied: Only Admins can modify the normal range.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final double? minPh = double.tryParse(_minController.text);
    final double? maxPh = double.tryParse(_maxController.text);

    if (minPh == null || maxPh == null || minPh >= maxPh) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid minimum and maximum values.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _firestoreRef.set({
        'min_ph': minPh,
        'max_ph': maxPh,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Normal Range updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to Firestore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      // --- INTEGRATED CUSTOM APP BAR ---
      appBar: CustomAppBar(
        title: 'pH Status & Settings',
        isAdmin: _localIsAdmin, // Use the local state here
        onLoginStateChanged: (bool newStatus) {
          // 1. Update the parent TapView so the rest of the app knows
          widget.onLoginStateChanged(newStatus);

          // 2. Update the local state to trigger a live UI refresh on this screen
          setState(() {
            _localIsAdmin = newStatus;
          });
        },
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFirestoreSettingsStream(),
            const SizedBox(height: 24),
            _buildRealtimeDBStream(),
          ],
        ),
      ),
    );
  }

  Widget _buildFirestoreSettingsStream() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestoreRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_isDataLoaded) {
          return const Card(
            elevation: 3,
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          _currentMinPh = (data['min_ph'] ?? 6.5).toDouble();
          _currentMaxPh = (data['max_ph'] ?? 7.5).toDouble();

          if (!_isDataLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _minController.text = _currentMinPh.toString();
                  _maxController.text = _currentMaxPh.toString();
                  _isDataLoaded = true;
                });
              }
            });
          }
        } else if (!_isDataLoaded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _minController.text = _currentMinPh.toString();
                _maxController.text = _currentMaxPh.toString();
                _isDataLoaded = true;
              });
            }
          });
        }

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings, color: Colors.blueGrey),
                    SizedBox(width: 10),
                    Text(
                      'Configure Normal Range',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Min pH',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _maxController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Max pH',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      // Use local state for button styling
                      backgroundColor: _localIsAdmin
                          ? Colors.blue
                          : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveRangeToFirestore,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _localIsAdmin ? Icons.save : Icons.lock,
                          ), // Use local state
                    label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRealtimeDBStream() {
    return StreamBuilder(
      stream: _rtdbRef.orderByKey().limitToLast(1).onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('No live pH data available.'));
        }

        final Map<dynamic, dynamic> dataMap =
            snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final latestKey = dataMap.keys.first;
        final sensorData = dataMap[latestKey];

        final double currentPh = (sensorData['ph'] ?? 0).toDouble();
        final int timestampMillis = (sensorData['timestamp'] ?? 0).toInt();

        DateTime lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(
          timestampMillis,
        );
        String formattedTime = DateFormat(
          'MMM dd, hh:mm:ss a',
        ).format(lastUpdateDate);

        Color statusColor;
        String statusText;
        IconData statusIcon;

        if (currentPh < _currentMinPh) {
          statusColor = Colors.orange;
          statusText = 'ACIDIC';
          statusIcon = Icons.warning_amber_rounded;
        } else if (currentPh > _currentMaxPh) {
          statusColor = Colors.purple;
          statusText = 'ALKALINE';
          statusIcon = Icons.warning_amber_rounded;
        } else {
          statusColor = Colors.green;
          statusText = 'NORMAL';
          statusIcon = Icons.check_circle_outline;
        }

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [statusColor.withOpacity(0.1), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              vertical: 30.0,
              horizontal: 20.0,
            ),
            child: Column(
              children: [
                Text(
                  'Live pH Reading',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 8),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      currentPh.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Last Updated: $formattedTime',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
