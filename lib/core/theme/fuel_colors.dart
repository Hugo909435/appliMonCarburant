import 'package:flutter/material.dart';

import '../../data/models/fuel_type.dart';

/// Color coding per fuel type, loosely inspired by the labels printed on
/// French pump nozzles so the eye can match a color to a fuel at a glance.
extension FuelColor on FuelType {
  Color get color {
    switch (this) {
      case FuelType.gazole:
        return const Color(0xFFD9A400);
      case FuelType.sp95:
        return const Color(0xFF2F8F5B);
      case FuelType.sp98:
        return const Color(0xFF1E6FA8);
      case FuelType.e10:
        return const Color(0xFF7CAF2A);
      case FuelType.e85:
        return const Color(0xFF8B5CB0);
      case FuelType.gplc:
        return const Color(0xFF2FA3AE);
    }
  }
}
