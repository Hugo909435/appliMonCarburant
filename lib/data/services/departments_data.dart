import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/department.dart';

class DepartmentsData {
  Map<String, Department>? _cache;

  Future<Map<String, Department>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/data/departments.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final result = json.map(
      (key, value) => MapEntry(key, Department.fromJson(key, value as Map<String, dynamic>)),
    );
    _cache = result;
    return result;
  }
}
