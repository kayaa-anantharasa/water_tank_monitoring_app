import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // Required for formatting the timestamp

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Reference to the 'SensorData' node in your Firebase Realtime Database
  final DatabaseReference _databaseReference = FirebaseDatabase.instance
      .ref()
      .child('SensorData');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade100, // Light background to make cards pop
      body: StreamBuilder(
        // Query the last added item to get the most recent sensor reading
        stream: _databaseReference.orderByKey().limitToLast(1).onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text('No sensor data available.'));
          }

          // Parse the Firebase snapshot Map
          final Map<dynamic, dynamic> dataMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          // Because we limited to 1, we get the single latest key and its values
          final latestKey = dataMap.keys.first;
          final sensorData = dataMap[latestKey];

          // Safely extract the data mapping to your database keys
          final double waterLevel = (sensorData['water_level_percent'] ?? 0)
              .toDouble();
          final double flowSensor1 = (sensorData['flow_sensor1'] ?? 0)
              .toDouble();
          final double flowSensor2 = (sensorData['flow_sensor2'] ?? 0)
              .toDouble();
          final bool pumpStatus = sensorData['pump_active'] ?? false;

          // Parse the timestamp
          final int timestampMillis = (sensorData['timestamp'] ?? 0).toInt();
          DateTime lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(
            timestampMillis,
          );

          // Format the date to be human-readable (e.g., "Oct 12, 02:30 PM")
          String formattedTime = DateFormat(
            'MMM dd, hh:mm a',
          ).format(lastUpdateDate);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Last Update Indicator ---
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.update, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Last Updated: $formattedTime',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // --- Sensor Cards ---
                _buildWaterLevelCard(waterLevel),
                const SizedBox(height: 16),
                _buildFlowCard(flowSensor1, flowSensor2),
                const SizedBox(height: 16),
                _buildPumpStatusCard(pumpStatus),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI Widget for Water Level ---
  Widget _buildWaterLevelCard(double waterLevel) {
    // Determine status color and text based on water level
    Color statusColor = waterLevel >= 75
        ? Colors.green
        : (waterLevel > 25 ? Colors.blue : Colors.red);
    String statusText = waterLevel >= 75
        ? 'HIGH'
        : (waterLevel > 25 ? 'NORMAL' : 'LOW');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Circular Progress Indicator representing the tank
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: waterLevel / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.blue.shade100,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  '${waterLevel.toInt()}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            // Textual Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Water Level',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${waterLevel.toInt()}%',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Widget for Flow Sensors (Inflow / Outflow) ---
  Widget _buildFlowCard(double inflow, double outflow) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Inlet Flow (flow_sensor1)
            Column(
              children: [
                const Text(
                  'Inlet Flow',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$inflow L/min',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              width: 1,
              height: 50,
              color: Colors.grey.shade300,
            ), // Vertical Divider
            // Outlet Flow (flow_sensor2)
            Column(
              children: [
                const Text(
                  'Outlet Flow',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$outflow L/min',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Widget for Pump Status ---
  Widget _buildPumpStatusCard(bool isPumpOn) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pump Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Row(
              children: [
                // Status Indicator Dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isPumpOn ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPumpOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isPumpOn ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
