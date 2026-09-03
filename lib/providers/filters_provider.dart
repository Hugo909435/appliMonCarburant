import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/fuel_type.dart';

final selectedFuelProvider = StateProvider<FuelType>((ref) => FuelType.gazole);
