import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// User-facing (French) explanation of why a location request failed, so
/// the UI can show it as-is instead of a raw exception.
class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class LocationService {
  Future<Position> getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure('Localisation refusée.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        "Localisation bloquée pour cette app. Autorise-la dans les réglages de ton téléphone.",
      );
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        'Active la localisation de ton téléphone pour utiliser cette fonction.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 12),
      );
    } on TimeoutException {
      throw const LocationFailure(
        "Impossible d'obtenir ta position (pas de signal GPS). Réessaie, si possible à l'extérieur.",
      );
    }
  }
}
