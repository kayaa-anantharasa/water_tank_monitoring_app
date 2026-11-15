import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class TankDetailsScreen extends StatefulWidget {
  const TankDetailsScreen({super.key});

  @override
  State<TankDetailsScreen> createState() => _TankDetailsScreenState();
}

class _TankDetailsScreenState extends State<TankDetailsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'SensorData',
  );

  // Define your total tank capacity in Liters here
  final double tankCapacityLiters = 1000.0;

  // --- Logic to calculate Time to Fill / Time to Empty ---
  String _calculateEstimation(
    double currentLevelPct,
    double inflow,
    double outflow,
  ) {
    double currentVolume = (currentLevelPct / 100) * tankCapacityLiters;
    double netFlow = inflow - outflow;

    if (netFlow == 0) {
      return "Water Level Stable\n(No Net Flow)";
    }

    if (netFlow > 0) {
      // Tank is filling
      double remainingVolume = tankCapacityLiters - currentVolume;
      if (remainingVolume <= 0) return "Tank is Full";

      double minutesToFill = remainingVolume / netFlow;
      int h = (minutesToFill / 60).floor();
      int m = (minutesToFill % 60).floor();
      return "Time to Fill:\n${h}h ${m}m";
    } else {
      // Tank is emptying
      if (currentVolume <= 0) return "Tank is Empty";

      double minutesToEmpty = currentVolume / netFlow.abs();
      int h = (minutesToEmpty / 60).floor();
      int m = (minutesToEmpty % 60).floor();
      return "Water Lasts For:\n${h}h ${m}m";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Tank Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: StreamBuilder(
        // Query the last 20 records to build the graph and get live status
        stream: _dbRef.orderByChild('timestamp').limitToLast(20).onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.snapshot.value == null) {
            return const Center(child: Text('No tank data available.'));
          }

          // Parse the data
          final Map<dynamic, dynamic> rawMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          List<Map<String, dynamic>> records = [];

          rawMap.forEach((key, value) {
            records.add({
              'water_level_percent': (value['water_level_percent'] ?? 0)
                  .toDouble(),
              'flow_sensor1': (value['flow_sensor1'] ?? 0).toDouble(),
              'flow_sensor2': (value['flow_sensor2'] ?? 0).toDouble(),
              'timestamp': (value['timestamp'] ?? 0).toInt(),
            });
          });

          // Sort by timestamp (oldest to newest)
          records.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

          // Extract the most recent data point for live estimations
          final latestRecord = records.last;
          final double currentLevel = latestRecord['water_level_percent'];
          final double inflow = latestRecord['flow_sensor1'];
          final double outflow = latestRecord['flow_sensor2'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLiveStatusCard(currentLevel, inflow, outflow),
                const SizedBox(height: 16),
                _buildEstimationCard(currentLevel, inflow, outflow),
                const SizedBox(height: 16),
                _buildHistoryGraph(records),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 1. Live Status Card (Level + Indicator) ---
  Widget _buildLiveStatusCard(
    double currentLevel,
    double inflow,
    double outflow,
  ) {
    Color levelColor = currentLevel > 75
        ? Colors.green
        : (currentLevel > 25 ? Colors.blue : Colors.red);
    String status = currentLevel > 75
        ? "HIGH"
        : (currentLevel > 25 ? "NORMAL" : "LOW");

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: currentLevel / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.blue.shade50,
                    color: levelColor,
                  ),
                ),
                Text(
                  '${currentLevel.toInt()}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: levelColor,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Water Level',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  // --- 2. Estimation Card (Calculated Output) ---
  Widget _buildEstimationCard(
    double currentLevel,
    double inflow,
    double outflow,
  ) {
    String estimationText = _calculateEstimation(currentLevel, inflow, outflow);
    double netFlow = inflow - outflow;

    // UI logic to show different icons/colors based on filling or emptying
    IconData statusIcon = netFlow > 0
        ? Icons.arrow_upward
        : (netFlow < 0 ? Icons.arrow_downward : Icons.compare_arrows);
    Color statusColor = netFlow > 0
        ? Colors.blue
        : (netFlow < 0 ? Colors.orange : Colors.grey);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: statusColor.withOpacity(0.1),
              child: Icon(statusIcon, color: statusColor, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                estimationText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. History Graph (Level Trend over time) ---
  Widget _buildHistoryGraph(List<Map<String, dynamic>> records) {
    // Generate FlSpots for the graph
    List<FlSpot> spots = [];
    double startTime = records.first['timestamp'].toDouble();

    for (var record in records) {
      // Normalize X-axis to prevent rendering issues with large timestamp numbers
      double xValue =
          (record['timestamp'] - startTime) /
          60000; // X is in minutes passed since first record
      double yValue = record['water_level_percent'];
      spots.add(FlSpot(xValue, yValue));
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Level Trend (Recent)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ), // Hide raw timestamps
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
