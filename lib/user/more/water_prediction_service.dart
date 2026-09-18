import 'dart:convert';
import 'package:http/http.dart' as http;

class WaterPredictionService {
  static const String baseUrl = 'http://localhost:8000';

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
