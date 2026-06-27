import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// Model class to map historical database entries smoothly
class SensorRecord {
  final String id;
  final double waterLevel;
  final double flowSensor1;
  final double flowSensor2;
  final double ph;
  final bool pumpActive;
  final DateTime timestamp;

  SensorRecord({
    required this.id,
    required this.waterLevel,
    required this.flowSensor1,
    required this.flowSensor2,
    required this.ph,
    required this.pumpActive,
    required this.timestamp,
  });

  factory SensorRecord.fromMap(String id, Map<dynamic, dynamic> map) {
    return SensorRecord(
      id: id,
      waterLevel: (map['water_level_percent'] ?? 0).toDouble(),
      flowSensor1: (map['flow_sensor1'] ?? 0).toDouble(),
      flowSensor2: (map['flow_sensor2'] ?? 0).toDouble(),
      ph: (map['ph'] ?? 0).toDouble(),
      pumpActive: map['pump_active'] ?? false, // Updated here
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'SensorData',
  );

  String _selectedFilter = '1W'; // Default filter: 1 Week
  DateTime? _customSelectedDate;

  // Filter logic applied locally on the database stream
  List<SensorRecord> _filterData(List<SensorRecord> records) {
    final now = DateTime.now();

    if (_selectedFilter == 'CUSTOM' && _customSelectedDate != null) {
      return records.where((r) {
        return r.timestamp.year == _customSelectedDate!.year &&
            r.timestamp.month == _customSelectedDate!.month &&
            r.timestamp.day == _customSelectedDate!.day;
      }).toList();
    }

    return records.where((r) {
      switch (_selectedFilter) {
        case '1D':
          return now.difference(r.timestamp).inDays < 1;
        case '1W':
          return now.difference(r.timestamp).inDays < 7;
        case '1M':
          return now.difference(r.timestamp).inDays < 30;
        case '1Y':
          return now.difference(r.timestamp).inDays < 365;
        default:
          return true;
      }
    }).toList();
  }

  // Helper method to launch standard Date Picker
  Future<void> _pickCustomDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _customSelectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedFilter = 'CUSTOM';
        _customSelectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(
            child: StreamBuilder(
              stream: _dbRef.orderByChild('timestamp').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(child: Text('No historical data found.'));
                }

                // Process and sort incoming map records chronologically
                final Map<dynamic, dynamic> rawMap =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                List<SensorRecord> allRecords = [];
                rawMap.forEach((key, value) {
                  allRecords.add(SensorRecord.fromMap(key, value));
                });
                allRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));

                // Apply active filters
                List<SensorRecord> filteredRecords = _filterData(allRecords);

                if (filteredRecords.isEmpty) {
                  return const Center(
                    child: Text(
                      'No data points match the selected time filter.',
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildChartCard(
                      'Water Level (%)',
                      _createWaterLevelSpots(filteredRecords),
                      Colors.blue,
                      filteredRecords,
                    ),
                    const SizedBox(height: 16),
                    _buildDualChartCard(
                      'Flow Rates (L/min)',
                      _createInflowSpots(filteredRecords),
                      _createOutflowSpots(filteredRecords),
                      filteredRecords,
                    ),
                    const SizedBox(height: 16),
                    _buildChartCard(
                      'pH Levels',
                      _createPHSpots(filteredRecords),
                      Colors.green,
                      filteredRecords,
                    ),
                    const SizedBox(height: 16),
                    _buildPumpChartCard(
                      'Pump Status (ON/OFF)',
                      _createPumpSpots(filteredRecords),
                      filteredRecords,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Top Filter Controls Component ---
  Widget _buildFilterBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildFilterButton('1D', '1 Day'),
          _buildFilterButton('1W', '1 Week'),
          _buildFilterButton('1M', '1 Month'),
          _buildFilterButton('1Y', '1 Year'),
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _selectedFilter == 'CUSTOM'
                  ? Colors.blue
                  : Colors.grey.shade700,
            ),
            onPressed: () => _pickCustomDate(context),
            tooltip: 'Select Specific Day',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filterKey, String label) {
    bool isActive = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: isActive ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filterKey;
            _customSelectedDate = null;
          });
        }
      },
    );
  }

  // --- Reusable Time Axis Formatter (X-Axis) ---
  AxisTitles _getBottomTitles(List<SensorRecord> records) {
    // Calculate interval to prevent label overlapping (show max ~5 labels)
    double interval = records.length > 5
        ? (records.length / 5).floorToDouble()
        : 1.0;
    if (interval == 0) interval = 1;

    return AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: interval,
        getTitlesWidget: (value, meta) {
          int index = value.toInt();
          if (index < 0 || index >= records.length) {
            return const SizedBox.shrink();
          }

          DateTime time = records[index].timestamp;
          String format;

          // Adapt formatting based on the selected time frame
          if (_selectedFilter == '1D' || _selectedFilter == 'CUSTOM') {
            format = 'HH:mm'; // Hours and minutes
          } else if (_selectedFilter == '1W') {
            format = 'E\nHH:mm'; // Day of week and time (e.g., Mon 14:30)
          } else {
            format = 'MMM dd'; // Month and day (e.g., Oct 12)
          }

          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              DateFormat(format).format(time),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Base Chart Render Card Container ---
  Widget _buildChartCard(
    String title,
    List<FlSpot> spots,
    Color lineGradientColor,
    List<SensorRecord> records,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
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
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: _getBottomTitles(
                      records,
                    ), // Show dynamic time at the bottom
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: lineGradientColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineGradientColor.withOpacity(0.1),
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

  // --- Dual Chart Card component (Inlet vs Outlet Comparison) ---
  Widget _buildDualChartCard(
    String title,
    List<FlSpot> inletSpots,
    List<FlSpot> outletSpots,
    List<SensorRecord> records,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildIndicatorDot(Colors.blue, 'Inlet'),
                    const SizedBox(width: 12),
                    _buildIndicatorDot(Colors.orange, 'Outlet'),
                  ],
                ),
              ],
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
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: _getBottomTitles(
                      records,
                    ), // Show dynamic time at the bottom
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: inletSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: outletSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
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

  // --- Pump Logging Binary Step Chart Card ---
  Widget _buildPumpChartCard(
    String title,
    List<FlSpot> spots,
    List<SensorRecord> records,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
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
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 1.0) {
                            return const Text(
                              'ON',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            );
                          }
                          if (value == 0.0) {
                            return const Text(
                              'OFF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    bottomTitles: _getBottomTitles(
                      records,
                    ), // Show dynamic time at the bottom
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false, // Step-graph formatting
                      color: Colors.purple,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.purple.withOpacity(0.05),
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

  Widget _buildIndicatorDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- Map Object Data lists out to Plot Coordinates ---
  List<FlSpot> _createWaterLevelSpots(List<SensorRecord> data) => List.generate(
    data.length,
    (i) => FlSpot(i.toDouble(), data[i].waterLevel),
  );

  List<FlSpot> _createInflowSpots(List<SensorRecord> data) => List.generate(
    data.length,
    (i) => FlSpot(i.toDouble(), data[i].flowSensor1),
  );

  List<FlSpot> _createOutflowSpots(List<SensorRecord> data) => List.generate(
    data.length,
    (i) => FlSpot(i.toDouble(), data[i].flowSensor2),
  );

  List<FlSpot> _createPHSpots(List<SensorRecord> data) =>
      List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i].ph));

  List<FlSpot> _createPumpSpots(List<SensorRecord> data) => List.generate(
    data.length,
    (i) => FlSpot(i.toDouble(), data[i].pumpActive ? 1.0 : 0.0), // Updated here
  );
}
