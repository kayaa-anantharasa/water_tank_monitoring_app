import 'package:flutter_test/flutter_test.dart';
import 'package:smart_water_tank/user/more/water_prediction_service.dart';

void main() {
  group('WaterPredictionService summary', () {
    test('buildPredictionSummary includes usage, level, refill and finish context', () {
      final service = WaterPredictionService();

      final summary = service.buildPredictionSummary(
        usagePredictions: [
          {'date': '2026-11-15', 'predicted_value': 120.0},
          {'date': '2026-11-16', 'predicted_value': 140.0},
        ],
        levelPredictions: [
          {'date': '2026-11-15', 'predicted_value': 70.0},
          {'date': '2026-11-16', 'predicted_value': 65.0},
        ],
        refillInfo: {
          'status': 'normal',
          'current_level': 65,
          'estimated_hours_remaining': 10.5,
          'estimated_datetime': '2026-11-16T08:00:00.000',
        },
        finishInfo: {
          'status': 'normal',
          'current_level': 65,
          'estimated_hours_remaining': 24.0,
          'estimated_datetime': '2026-11-17T12:00:00.000',
        },
      );

      expect(summary, contains('Usage forecast'));
      expect(summary, contains('Level forecast'));
      expect(summary, contains('Refill timing'));
      expect(summary, contains('Water finish timing'));
      expect(summary, contains('65%'));
      expect(summary, contains('10.5 hours'));
      expect(summary, contains('24.0 hours'));
    });
  });
}
