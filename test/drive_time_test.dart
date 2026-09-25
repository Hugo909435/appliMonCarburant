import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/core/utils/drive_time.dart';
import 'package:mon_carburant_app/core/utils/formatters.dart';

void main() {
  group('estimateDriveTime', () {
    test('une station à 1 km à vol d’oiseau est à quelques minutes', () {
      // 1,3 km de route en ville à 25 km/h ≈ 3 min.
      expect(estimateDriveTime(1).inSeconds, closeTo(187, 1));
    });

    test('une station plus loin ne paraît jamais plus proche', () {
      var previous = Duration.zero;
      for (var km = 0.0; km <= 100; km += 0.5) {
        final t = estimateDriveTime(km);
        expect(t >= previous, isTrue, reason: 'à $km km');
        previous = t;
      }
    });
  });

  group('formatDriveTime', () {
    test('arrondit à la minute supérieure, jamais « 0 min »', () {
      expect(formatDriveTime(Duration.zero), '1 min');
      expect(formatDriveTime(const Duration(seconds: 61)), '2 min');
      expect(formatDriveTime(const Duration(minutes: 59)), '59 min');
    });

    test('passe en heures au-delà de 60 min', () {
      expect(formatDriveTime(const Duration(minutes: 60)), '1 h 00');
      expect(formatDriveTime(const Duration(minutes: 65)), '1 h 05');
    });
  });
}
