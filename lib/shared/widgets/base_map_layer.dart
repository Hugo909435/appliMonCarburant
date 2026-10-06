import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/config/app_config.dart';

/// Fond affiché là où une tuile n'est pas encore arrivée : la couleur des
/// terres de la carte plutôt que le gris par défaut de flutter_map, pour
/// qu'une tuile en retard ne fasse pas un trou.
const kMapBackground = Color(0xFFF2EFE9);

/// The map's background: raster tiles from [AppConfig.tileUrlTemplate],
/// kept on disk so an area already seen shows at once, offline included,
/// and doesn't count again against the provider's quota. Goes in a
/// [FlutterMap]'s children, below the markers.
class BaseMapLayer extends StatelessWidget {
  const BaseMapLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: AppConfig.tileUrlTemplate,
      userAgentPackageName: AppConfig.packageName,
      tileProvider: _CachedTileProvider(),
      // Tuiles @2x sur les écrans haute densité, si le gabarit les prévoit :
      // une carte nette pour le même nombre de requêtes.
      retinaMode:
          AppConfig.tileUrlTemplate.contains('{r}') &&
          RetinaMode.isHighDensity(context),
      // Une couronne de tuiles chargée autour de l'écran, et davantage
      // gardée en mémoire : moins de bords gris en faisant glisser la carte
      // ou en revenant sur ses pas.
      panBuffer: 1,
      keepBuffer: 4,
    );
  }
}

class _CachedTileProvider extends TileProvider {
  // Map modifiable : TileLayer y ajoute son en-tête User-Agent, tiré de
  // userAgentPackageName.
  _CachedTileProvider() : super(headers: {});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      CachedNetworkImageProvider(
        getTileUrl(coordinates, options),
        headers: headers,
      );
}
