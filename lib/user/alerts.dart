import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// --- Data Model for Alerts ---
class AlertData {
  final String title;
  final String description;
  final String timeText;
  final Color uiColor;
  final IconData uiIcon;
  final PdfColor pdfColor;

  AlertData({
    required this.title,
    required this.description,
    required this.timeText,
    required this.uiColor,
    required this.uiIcon,
    required this.pdfColor,
  });
}

class AlertsScreen extends StatefulWidget {
  // Pass this variable when navigating to this screen
  final bool isAdmin;

  const AlertsScreen({
    super.key,
    this.isAdmin = false, // Defaults to false (Guest Mode)
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child(
    'SensorData',
  );

  // --- PDF Generation Function ---
  Future<void> _generateAndSharePDF(List<AlertData> currentAlerts) async {
    final pdf = pw.Document();

    final String currentDate = DateFormat(
      'yyyy-MM-dd hh:mm a',
    ).format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // PDF Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'SMART WATER TANK SYSTEM',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'OFFICIAL MAINTENANCE NOTICE',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.red800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Report Generated: $currentDate',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 20),

              // PDF Body
              if (currentAlerts.isEmpty)
                pw.Center(
                  child: pw.Text(
                    'SYSTEM NORMAL: No active alerts at this time.',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green,
                    ),
                  ),
                )
              else
                pw.Text(
                  'ACTION REQUIRED:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 10),

              // Iterate through active alerts and draw boxes for each
              ...currentAlerts.map((alert) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: alert.pdfColor, width: 2),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            alert.title,
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: alert.pdfColor,
                            ),
                          ),
                          pw.Text(
                            alert.timeText,
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        alert.description,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              }),

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text(
                  'End of Report',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // This will open a bottom sheet on the phone allowing the user to Save to Files, Print, or WhatsApp it.
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Tank_Alert_Notice.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _dbRef.orderByChild('timestamp').limitToLast(1).onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        List<AlertData> activeAlerts = [];
        bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        bool hasError = snapshot.hasError;

        if (!isLoading && !hasError) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            // Critical Maintenance Alert (No Data)
            activeAlerts.add(
              AlertData(
                title: 'Critical Maintenance',
                description:
                    'No sensor data found in the database. Please check the hardware connection.',
                timeText: 'Now',
                uiColor: Colors.orange,
                uiIcon: Icons.warning_rounded,
                pdfColor: PdfColors.orange,
              ),
            );
          } else {
            // Parse Database
            final Map<dynamic, dynamic> dataMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            final latestKey = dataMap.keys.first;
            final sensorData = dataMap[latestKey];

            final double waterLevel = (sensorData['water_level_percent'] ?? 0)
                .toDouble();
            final double flowSensor2 = (sensorData['flow_sensor2'] ?? 0)
                .toDouble(); // Outflow

            // Updated to match your database structure
            final bool pumpStatus = sensorData['pump_active'] ?? false;
            final int timestampMillis = (sensorData['timestamp'] ?? 0).toInt();

            DateTime lastUpdateDate = DateTime.fromMillisecondsSinceEpoch(
              timestampMillis,
            );
            String formattedTime = DateFormat(
              'hh:mm a, MMM dd',
            ).format(lastUpdateDate);

            // 1. Maintenance Alert (Offline for > 60 mins)
            final int minutesSinceLastUpdate = DateTime.now()
                .difference(lastUpdateDate)
                .inMinutes;
            if (minutesSinceLastUpdate >= 60) {
              activeAlerts.add(
                AlertData(
                  title: 'System Offline (Maintenance Needed)',
                  description:
                      'No data received from sensors in the last $minutesSinceLastUpdate minutes. Please check power and Wi-Fi.',
                  timeText: formattedTime,
                  uiColor: Colors.orange,
                  uiIcon: Icons.wifi_off,
                  pdfColor: PdfColors.orange,
                ),
              );
            }

            // 2. Low Water Alert
            if (waterLevel <= 25.0) {
              activeAlerts.add(
                AlertData(
                  title: 'Low Water Level',
                  description:
                      'The tank water level has dropped to ${waterLevel.toInt()}%. Consider turning on the pump.',
                  timeText: formattedTime,
                  uiColor: Colors.blueAccent,
                  uiIcon: Icons.water_drop,
                  pdfColor: PdfColors.blue,
                ),
              );
            }

            // 3. Leakage Alert
            bool suspectedLeak = (pumpStatus == false && flowSensor2 > 0.5);
            if (suspectedLeak) {
              activeAlerts.add(
                AlertData(
                  title: 'Suspected Leakage Detected!',
                  description:
                      'Outflow detected (${flowSensor2} L/min) while the pump is OFF. Check pipes and valves immediately.',
                  timeText: formattedTime,
                  uiColor: Colors.redAccent,
                  uiIcon: Icons.plumbing,
                  pdfColor: PdfColors.red,
                ),
              );
            }
          }
        }

        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: AppBar(
            title: const Text('System Alerts'),
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 2,
          ),

          // --- Security Check on the Floating Action Button ---
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              // Intercept the click if the user is not an admin
              if (!widget.isAdmin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please login as Admin to download reports',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return; // Stop the function here
              }

              // If they are an admin, proceed with generating the PDF
              _generateAndSharePDF(activeAlerts);
            },
            // Change colors and icons dynamically based on admin status
            backgroundColor: widget.isAdmin
                ? Colors.redAccent
                : Colors.grey.shade400,
            foregroundColor: Colors.white,
            icon: Icon(widget.isAdmin ? Icons.picture_as_pdf : Icons.lock),
            label: Text(
              widget.isAdmin ? 'Download Notice' : 'Admin Only',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          body: Builder(
            builder: (context) {
              if (isLoading)
                return const Center(child: CircularProgressIndicator());
              if (hasError)
                return const Center(child: Text('Error loading alerts.'));

              if (activeAlerts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'System Normal',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'There are no active alerts at this time.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: 80.0,
                ), // Bottom padding for FAB
                itemCount: activeAlerts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final alert = activeAlerts[index];
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: alert.uiColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              alert.uiIcon,
                              color: alert.uiColor,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        alert.title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: alert.uiColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      alert.timeText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  alert.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
