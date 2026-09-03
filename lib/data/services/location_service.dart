import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    if (!await Geolocator.isLocationServiceEnabled()) return null;

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
  }
}
