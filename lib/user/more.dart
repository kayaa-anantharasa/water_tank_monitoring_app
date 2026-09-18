import 'package:flutter/material.dart';
import 'package:smart_water_tank/user/more/AI_chatbot.dart';
import 'package:smart_water_tank/user/more/PHstatus.dart';
import 'package:smart_water_tank/user/more/pump_control.dart';
import 'package:smart_water_tank/user/more/tank_details.dart';
import 'package:smart_water_tank/user/more/water_prediction_screen.dart';

class MoreScreen extends StatelessWidget {
  // Pass this variable from your login state (true if Admin, false if Guest)
  final bool isAdmin;
  final Function(bool) onLoginStateChanged;

  const MoreScreen({
    super.key,
    this.isAdmin = false,
    required this.onLoginStateChanged,
  }); // Defaults to false (Guest Mode)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Settings & More',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Menu Options
          _buildMenuCard(
            context: context,
            title: 'pH Status',
            subtitle: 'Monitor water acidity and alkalinity',
            icon: Icons.science,
            iconColor: Colors.teal,
            destinationPage: PHStatusScreen(
              isAdmin: isAdmin,
              onLoginStateChanged: onLoginStateChanged, // Pass it down
            ),
          ),
          const SizedBox(height: 12),

          _buildMenuCard(
            context: context,
            title: 'Tank Details',
            subtitle: 'Capacity, dimensions, and maintenance',
            icon: Icons.propane_tank,
            iconColor: Colors.blueGrey,
            destinationPage: TankDetailsScreen(),
          ),
          const SizedBox(height: 12),

          _buildMenuCard(
            context: context,
            title: 'Water Prediction',
            subtitle: 'Usage trend, refill timing, and water level forecasts',
            icon: Icons.auto_graph,
            iconColor: Colors.indigo,
            destinationPage: const WaterPredictionScreen(),
          ),
          const SizedBox(height: 12),

          _buildMenuCard(
            context: context,
            title: 'AI Chatbot',
            subtitle: 'Get smart assistance and insights',
            icon: Icons.smart_toy,
            iconColor: Colors.purple,
            destinationPage: const AIChatbotScreen(),
          ),
          const SizedBox(height: 12),

          // Pump Control - Requires Admin Access
          _buildMenuCard(
            context: context,
            title: 'Pump Control',
            subtitle: 'Manual override and scheduling',
            icon: Icons.power_settings_new,
            iconColor: Colors.redAccent,
            destinationPage: const PumpControlScreen(),
            requiresAdmin: true, // This locks the button
          ),
        ],
      ),
    );
  }

  // Helper widget to create a premium looking menu card
  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget destinationPage,
    bool requiresAdmin = false, // Default to false for public pages
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // --- Security Check ---
          if (requiresAdmin && !isAdmin) {
            // Show error message and stop navigation
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please login as Admin to access Pump Control',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
            return; // Exit the function early
          }

          // If allowed, navigate to the page
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destinationPage),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            trailing: Icon(
              requiresAdmin && !isAdmin ? Icons.lock : Icons.arrow_forward_ios,
              size: 18,
              color: requiresAdmin && !isAdmin ? Colors.redAccent : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
