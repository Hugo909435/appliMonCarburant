import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brands/brand_catalog.dart';
import '../../providers/station_brands_provider.dart';

/// A station brand's logo: `assets/logos/<key>.png` when that file is
/// bundled, otherwise a rounded badge in the brand's colors.
class BrandLogo extends ConsumerWidget {
  const BrandLogo({super.key, required this.brand, this.size = 32});

  final FuelBrand brand;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetPath = 'assets/logos/${brand.key}.png';
    final hasAsset = ref.watch(
      brandLogoAssetsProvider.select(
        (v) => v.valueOrNull?.contains(assetPath) ?? false,
      ),
    );
    final radius = BorderRadius.circular(size * 0.24);

    return Tooltip(
      message: brand.name,
      child: SizedBox.square(
        dimension: size,
        child: hasAsset
            // Logos sit on white: the outline and shadow keep them from
            // melting into light map tiles or white cards.
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: radius,
                  border: Border.all(color: const Color(0x33000000)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: brand.background,
                  borderRadius: radius,
                  border: Border.all(
                    color: brand.border ?? Colors.white,
                    width: size >= 28 ? 2 : 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(size * 0.14),
                  child: FittedBox(
                    child: Text(
                      brand.short,
                      style: TextStyle(
                        color: brand.foreground,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// [BrandLogo] for a station id, or nothing when its brand is unknown.
class StationBrandLogo extends ConsumerWidget {
  const StationBrandLogo({
    super.key,
    required this.stationId,
    this.size = 32,
    this.placeholder,
  });

  final String stationId;
  final double size;

  /// Shown instead when the station has no known brand.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(stationBrandProvider(stationId));
    if (brand == null) return placeholder ?? const SizedBox.shrink();
    return BrandLogo(brand: brand, size: size);
  }
}
