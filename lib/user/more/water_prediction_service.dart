import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WaterPredictionService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    return 'http://10.0.2.2:8000';
  }

  Future<String> getPredictionContext({
    int daysAhead = 7,
    double threshold = 50,
    double? currentWaterLevel,
  }) async {
    try {
      final usagePredictions = await getUsagePrediction(daysAhead: daysAhead);
      final levelPredictions = await getLevelPrediction(daysAhead: daysAhead);
      final refillInfo = await getNextRefillPrediction(threshold: threshold);
      final finishInfo = await getWaterFinishPrediction();
      var pumpText = 'Pump status prediction: current water level unavailable.';
      if (currentWaterLevel != null) {
        try {
          final pumpStatus = await getPumpPrediction(currentWaterLevel);
          pumpText =
              'Pump status prediction at ${currentWaterLevel.toStringAsFixed(1)}% water level: $pumpStatus';
        } catch (_) {
          pumpText = 'Pump status prediction is unavailable right now.';
        }
      }

      final usageValue = usagePredictions.isNotEmpty
          ? usagePredictions.last['predicted_value']
          : 'No usage forecast available';
      final levelValue = levelPredictions.isNotEmpty
          ? levelPredictions.last['predicted_value']
          : 'No level forecast available';

      final refillText = _formatApiTiming(refillInfo, 'Refill');
      final finishText = _formatApiTiming(finishInfo, 'Water finish');

      return '''
Water prediction context:
- Usage forecast: $usageValue
- Level forecast: $levelValue
- $pumpText
- $refillText
- $finishText
''';
    } catch (e) {
      return 'Water prediction API is unavailable right now: $e';
    }
  }

  String _formatApiTiming(Map<String, dynamic> info, String label) {
    if (info.isEmpty) {
      return '$label timing: No prediction data available.';
    }

    final status = info['status'];
    if (status == 'error') {
      return '$label timing: Prediction service error: ${info['message'] ?? 'unknown error'}';
    }
    if (status == 'insufficient_data') {
      return '$label timing: ${info['message'] ?? 'Not enough data to estimate timing yet.'}';
    }
    if (status == 'already_low' || status == 'already_empty') {
      return '$label timing: ${info['message'] ?? 'Tank already at an alert level.'}';
    }

    final currentLevel = info['current_level'];
    final hours = info['estimated_hours_remaining'];
    final date = info['estimated_datetime'];
    final levelText = currentLevel == null ? 'current level unknown' : '$currentLevel%';
    final timeText = hours is num ? '${hours.toStringAsFixed(1)} hours' : 'not available';
    final dateText = date == null ? '' : ' Expected around $date.';

    return '$label timing: current level is $levelText and is estimated to take about $timeText.$dateText';
  }

  Future<List<Map<String, dynamic>>> getUsagePrediction({
    int daysAhead = 7,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/predict/usage?days_ahead=$daysAhead'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['predictions']);
    } else {
      throw Exception(
        'Failed to load usage prediction: ${response.statusCode}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getLevelPrediction({
    int daysAhead = 7,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/predict/level?days_ahead=$daysAhead'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['predictions']);
    } else {
      throw Exception(
        'Failed to load level prediction: ${response.statusCode}',
      );
    }
  }

  Future<String> getPumpPrediction(double waterLevel) async {
    final response = await http.get(
      Uri.parse('$baseUrl/predict/pump?water_level=$waterLevel'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['predicted_pump_status'];
    } else {
      throw Exception('Failed to load pump prediction: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getNextRefillPrediction({
    double threshold = 50,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/predict/next-refill?threshold=$threshold'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to load next-refill prediction: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> getWaterFinishPrediction() async {
    final response = await http.get(Uri.parse('$baseUrl/predict/water-finish'));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to load water-finish prediction: ${response.statusCode}',
      );
    }
  }
}
