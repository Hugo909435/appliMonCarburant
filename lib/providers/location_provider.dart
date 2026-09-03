import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/services/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

class UserLocationNotifier extends AsyncNotifier<Position?> {
  @override
  Future<Position?> build() async => null;

  Future<void> requestLocation() async {
    state = const AsyncLoading<Position?>();
    state = await AsyncValue.guard(() => ref.read(locationServiceProvider).getCurrentPosition());
  }
}

final userLocationProvider = AsyncNotifierProvider<UserLocationNotifier, Position?>(
  UserLocationNotifier.new,
);
