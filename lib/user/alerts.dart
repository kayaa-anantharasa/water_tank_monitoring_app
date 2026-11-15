import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    try {
      final pdf = pw.Document();
      final reportDate = DateFormat('dd MMMM yyyy').format(DateTime.now());
        final issueAlerts = currentAlerts
          .where((alert) => !alert.title.startsWith('Water Pump Status:'))
          .toList();
        final pumpStatusAlert = currentAlerts
          .where((alert) => alert.title.startsWith('Water Pump Status:'))
          .firstOrNull;

      final umsLogoBytes =
          (await rootBundle.load('assets/images/ums_logo.png'))
              .buffer
              .asUint8List();

      final jppLogoBytes =
          (await rootBundle.load('assets/images/jpp_logo.png'))
              .buffer
              .asUint8List();

      final umsLogo = pw.MemoryImage(umsLogoBytes);
      final jppLogo = pw.MemoryImage(jppLogoBytes);

  // Formal academic-document style
  final normalStyle = pw.TextStyle(
    font: pw.Font.times(),
    fontSize: 9,
  );

  final boldStyle = pw.TextStyle(
    font: pw.Font.timesBold(),
    fontSize: 9,
  );

  // Section heading
  pw.Widget sectionHeading(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 3),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: pw.Font.timesBold(),
          fontSize: 10,
        ),
      ),
    );
  }

  // Reusable formal table
  pw.Widget reportTable(
    List<List<String>> rows,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey700,
        width: 0.6,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.1),
        1: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            'Item',
            'Details',
          ].map((value) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                value,
                style: boldStyle,
              ),
            );
          }).toList(),
        ),
        ...rows.map((row) {
          return pw.TableRow(
            children: row.map((value) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(
                  value,
                  style: normalStyle,
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(34, 24, 34, 24),
          theme: pw.ThemeData.withFont(
            base: pw.Font.times(),
            bold: pw.Font.timesBold(),
          ),
          build: (context) => pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.SizedBox(
              width: PdfPageFormat.a4.width - 68,
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                // Institutional report header
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(
                      umsLogo,
                      width: 58,
                      height: 58,
                      fit: pw.BoxFit.contain,
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text(
                            'UNIVERSITI MALAYSIA SABAH',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              font: pw.Font.timesBold(),
                              fontSize: 10,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'SMART WATER TANK MONITORING SYSTEM',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              font: pw.Font.timesBold(),
                              fontSize: 9,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'MAINTENANCE REQUEST REPORT',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              font: pw.Font.timesBold(),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Image(
                      jppLogo,
                      width: 58,
                      height: 58,
                      fit: pw.BoxFit.contain,
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: PdfColors.black),
                pw.SizedBox(height: 4),
                // Report reference and date
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Reference No.: WMS-RPT-2026-001', style: boldStyle),
                    pw.Text('Date: $reportDate', style: boldStyle),
                  ],
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'To: Jabatan Pembangunan dan Penyelenggaraan (JPP), '
                  'Universiti Malaysia Sabah',
                  style: normalStyle,
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Subject: Maintenance Request for Tank A - '
                  'Kolej Kediaman Tun Mustapha',
                  style: boldStyle,
                ),
                pw.SizedBox(height: 5),
                pw.Text('Dear Maintenance Team,', style: normalStyle),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Based on the monitoring records available to the Smart Water '
                  'Tank Monitoring System, the following tank information and '
                  'detected conditions are recorded for maintenance reference.',
                  textAlign: pw.TextAlign.justify,
                  style: normalStyle.copyWith(height: 1.2),
                ),
                sectionHeading('1. TANK INFORMATION'),
                reportTable([
                  ['Tank Name', 'Tank A'],
                  [
                    'Location',
                    'Kolej Kediaman Tun Mustapha, Universiti Malaysia Sabah',
                  ],
                  [
                    'Last Recorded Water Level',
                    'Refer to the latest sensor record',
                  ],
                  [
                    'Pump Status',
                    pumpStatusAlert?.title.endsWith('ON') == true
                        ? 'ON - Operating'
                        : pumpStatusAlert?.title.endsWith('OFF') == true
                            ? 'OFF - Not operating'
                            : 'Unavailable',
                  ],
                  [
                    'System Status',
                    issueAlerts.any((alert) => alert.title.contains('Offline'))
                        ? 'Offline / Maintenance Required'
                      : issueAlerts.isEmpty
                            ? 'No active alert'
                            : 'Active Alert Detected',
                  ],
                  [
                    'Last Sensor Update',
                    currentAlerts.isNotEmpty
                        ? currentAlerts.first.timeText
                        : 'No active alert',
                  ],
                  [
                    'Maintenance Priority',
                    issueAlerts.any(
                      (alert) =>
                          alert.title.contains('Critical') ||
                          alert.title.contains('Leakage'),
                    )
                        ? 'High - Requires Attention'
                        : issueAlerts.isEmpty
                            ? 'Normal'
                            : 'Review Required',
                  ],
                ]),
                sectionHeading('2. DETECTED CONDITIONS'),
                if (issueAlerts.isEmpty)
                  pw.Text(
                    'System Online: No active maintenance issue detected.',
                    style: normalStyle,
                  )
                else
                  ...issueAlerts.map((alert) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            alert.title,
                            style: boldStyle.copyWith(color: alert.pdfColor),
                          ),
                          pw.Text(
                            alert.description,
                            textAlign: pw.TextAlign.justify,
                            style: normalStyle.copyWith(height: 1.15),
                          ),
                          pw.Text(
                            'Recorded Time: ${alert.timeText}',
                            style: pw.TextStyle(
                              font: pw.Font.timesItalic(),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                sectionHeading('3. TANK MAINTENANCE RECORDS'),
                reportTable([
                  ['Received / Inspected By', '________________________'],
                  ['Inspection Date and Time', '________________________'],
                  ['Findings / Remarks', '________________________'],
                  [
                    'Maintenance Performed / Action Taken',
                    '________________________',
                  ],
                  ['Completion Status', 'Pending / In Progress / Resolved'],
                  ['Signature', '________________________'],
                ]),
                pw.SizedBox(height: 6),
                pw.Text('Yours faithfully,', style: normalStyle),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Smart Water Tank Monitoring System',
                  style: boldStyle,
                ),
                pw.Text('Universiti Malaysia Sabah', style: normalStyle),
                ],
              ),
            ),
          ),
        ),
      );

          await Printing.sharePdf(
            bytes: await pdf.save(),
            filename: 'Tank_Maintenance_Report.pdf',
          );

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'PDF downloaded successfully',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to download PDF. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            final double? ph = double.tryParse(
              '${sensorData['ph'] ?? ''}',
            );

            final dynamic rawPumpStatus = sensorData['pump_active'];
            final bool? pumpStatus = rawPumpStatus is bool
              ? rawPumpStatus
              : rawPumpStatus is num
                ? rawPumpStatus != 0
                : rawPumpStatus is String
                  ? rawPumpStatus.toLowerCase() == 'on' ||
                      rawPumpStatus.toLowerCase() == 'true' ||
                      rawPumpStatus == '1'
                    ? true
                    : rawPumpStatus.toLowerCase() == 'off' ||
                        rawPumpStatus.toLowerCase() == 'false' ||
                        rawPumpStatus == '0'
                      ? false
                      : null
                  : null;
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

            // 3. Abnormal pH Alert
            if (ph != null && (ph < 6.5 || ph > 8.5)) {
              activeAlerts.add(
                AlertData(
                  title: 'Abnormal pH Level',
                  description:
                      'The recorded pH is ${ph.toStringAsFixed(2)}, outside the safe range of 6.5 to 8.5. Please inspect the water quality.',
                  timeText: formattedTime,
                  uiColor: Colors.deepOrange,
                  uiIcon: Icons.science,
                  pdfColor: PdfColors.deepOrange,
                ),
              );
            }

            // 4. Pump Status
            if (pumpStatus != null) {
              activeAlerts.add(
                AlertData(
                  title: pumpStatus
                      ? 'Water Pump Status: ON'
                      : 'Water Pump Status: OFF',
                  description: pumpStatus
                      ? 'The water pump is operating.'
                      : 'The water pump is not operating.',
                  timeText: formattedTime,
                  uiColor: pumpStatus ? Colors.green : Colors.orange,
                  uiIcon: pumpStatus ? Icons.power : Icons.power_off,
                  pdfColor: pumpStatus ? PdfColors.green : PdfColors.orange,
                ),
              );
            }

            // 5. Leakage Alert
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
            onPressed: () async {
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
              await _generateAndSharePDF(activeAlerts);
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
