import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brands/brand_catalog.dart';
import '../../core/brands/logo_metrics.dart';
import '../../providers/station_brands_provider.dart';

/// Hauteur minimale, en pixels logiques, du dessin d'un logo pour qu'il reste
/// identifiable. En dessous, [BrandLogo] montre le badge de l'enseigne.
const _minDrawnLogoHeight = 9.0;

/// Si le vrai logo mérite d'être montré à [size], plutôt que le badge coloré.
///
/// Certains fichiers sont des logotypes larges (« E.Leclerc », « SPAR ») qui
/// n'occupent qu'une bande du carré de 256 px. `BoxFit.contain` ajuste le
/// carré entier et non le dessin : sur un marqueur de 22 px, cette bande
/// tombe à 3 ou 4 px de haut et ne veut plus rien dire. Le badge, lui, reste
/// lisible à toute taille.
///
/// La décision se prend sur une mesure du fichier
/// ([logoContentHeightFraction]), pas sur une liste d'enseignes : déposer un
/// logo plus compact et relancer `tool/measure_logos.dart` suffit à faire
/// revenir le vrai logo.
@visibleForTesting
bool shouldDrawLogo(String brandKey, double size, {required bool hasAsset}) {
  if (!hasAsset) return false;
  final drawnHeight = size * (logoContentHeightFraction[brandKey] ?? 1);
  return drawnHeight >= _minDrawnLogoHeight;
}

/// Forme du cadre dans lequel un [BrandLogo] est dessiné.
enum BrandLogoShape {
  /// Carré aux coins arrondis : la forme des listes et des fiches.
  rounded,

  /// Disque : la pastille des marqueurs de carte.
  circle,
}

/// Part du côté d'un disque occupée par le carré qui y est inscrit (1 / √2).
const _inscribedSquareRatio = 0.7071;

/// Côté réellement dessiné pour un logo de côté [size].
///
/// Dans un disque, le dessin est restreint au carré inscrit : sans cela le
/// rond mangerait les bords du logo. C'est donc sur cette taille réduite, et
/// non sur [size], que se juge la lisibilité d'un logo rond.
@visibleForTesting
double drawnLogoSize(double size, BrandLogoShape shape) =>
    shape == BrandLogoShape.circle ? size * _inscribedSquareRatio : size;

/// A station brand's logo: `assets/logos/<key>.png` when that file is bundled
/// and large enough to read at the requested size, otherwise a rounded badge
/// in the brand's colors.
class BrandLogo extends ConsumerWidget {
  const BrandLogo({
    super.key,
    required this.brand,
    this.size = 32,
    this.shape = BrandLogoShape.rounded,
  });

  final FuelBrand brand;
  final double size;
  final BrandLogoShape shape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetPath = 'assets/logos/${brand.key}.png';
    final hasAsset = ref.watch(
      brandLogoAssetsProvider.select(
        (v) => v.valueOrNull?.contains(assetPath) ?? false,
      ),
    );
    final isCircle = shape == BrandLogoShape.circle;
    final radius = isCircle ? null : BorderRadius.circular(size * 0.24);
    // Un logo rond ne dispose que du carré inscrit : c'est à cette taille-là
    // qu'il faut juger s'il reste lisible, et l'y confiner.
    final drawnSize = drawnLogoSize(size, shape);
    final inset = (size - drawnSize) / 2;
    final useLogo = shouldDrawLogo(brand.key, drawnSize, hasAsset: hasAsset);

    return Tooltip(
      message: brand.name,
      child: SizedBox.square(
        dimension: size,
        child: useLogo
            // Logos sit on white: the outline and shadow keep them from
            // melting into light map tiles or white cards.
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: radius,
                  border: Border.all(color: const Color(0x33000000)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 2),
                  ],
                ),
                child: Padding(
                  // Le retrait suffit à tenir le dessin dans le rond, sans
                  // clip qui lui rognerait les bords.
                  padding: EdgeInsets.all(inset),
                  child: isCircle
                      ? Image.asset(
                          assetPath,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        )
                      : ClipRRect(
                          borderRadius: radius!,
                          child: Image.asset(
                            assetPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: brand.background,
                  shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
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
                  padding: EdgeInsets.all(
                    isCircle ? inset + size * 0.05 : size * 0.14,
                  ),
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
