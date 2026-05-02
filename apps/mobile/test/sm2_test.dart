import 'package:flashmind_mobile/data/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applySm2', () {
    test('resets repetitions and schedules tomorrow when quality is low', () {
      final result = applySm2(
        easeFactor: 2.5,
        intervalDays: 6,
        repetitions: 2,
        quality: 0,
      );

      expect(result.repetitions, 0);
      expect(result.intervalDays, 1);
      expect(result.easeFactor, lessThan(2.5));
      expect(result.easeFactor, greaterThanOrEqualTo(1.3));
    });

    test('graduates a new successful card to one day', () {
      final result = applySm2(
        easeFactor: 2.5,
        intervalDays: 0,
        repetitions: 0,
        quality: 5,
      );

      expect(result.repetitions, 1);
      expect(result.intervalDays, 1);
      expect(result.easeFactor, greaterThan(2.5));
    });

    test('uses six days for the second successful repetition', () {
      final result = applySm2(
        easeFactor: 2.5,
        intervalDays: 1,
        repetitions: 1,
        quality: 4,
      );

      expect(result.repetitions, 2);
      expect(result.intervalDays, 6);
      expect(result.easeFactor, closeTo(2.5, 0.001));
    });
  });
}
