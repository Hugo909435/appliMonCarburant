import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/brands/brand_catalog.dart';

/// Brand of each station id, precomputed from OpenStreetMap by
/// tool/build_station_brands.dart and shipped with the app (~80 % of
/// stations). Stations missing from it just show no logo.
final stationBrandsProvider = FutureProvider<Map<String, FuelBrand>>((
  ref,
) async {
  final raw = jsonDecode(
    await rootBundle.loadString('assets/data/station_brands.json'),
  ) as Map<String, dynamic>;
  // Share one FuelBrand instance per key instead of building ~7 000.
  final byKey = <String, FuelBrand?>{};
  final result = <String, FuelBrand>{};
  raw.forEach((stationId, key) {
    final brand = byKey.putIfAbsent(key as String, () => brandForKey(key));
    if (brand != null) result[stationId] = brand;
  });
  return result;
});

/// Brand of a single station, or null (unknown, or still loading).
final stationBrandProvider = Provider.family<FuelBrand?, String>(
  (ref, stationId) =>
      ref.watch(stationBrandsProvider.select((v) => v.valueOrNull?[stationId])),
);

/// Logo files actually bundled under assets/logos/, so [BrandLogo] only
/// tries an image when one exists (and falls back to a badge otherwise).
final brandLogoAssetsProvider = FutureProvider<Set<String>>((ref) async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  return manifest
      .listAssets()
      .where((a) => a.startsWith('assets/logos/') && a.endsWith('.png'))
      .toSet();
});
