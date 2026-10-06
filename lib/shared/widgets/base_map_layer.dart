import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../core/config/app_config.dart';

/// The vector map style, read once (style JSON, tile source, sprites) and
/// shared by every map of the app.
final mapStyleProvider = FutureProvider<Style>(
  (ref) => StyleReader(uri: AppConfig.mapStyleUrl).read(),
);

/// The map's background: OpenFreeMap vector tiles, or raster tiles when
/// [AppConfig.tileUrlTemplate] is set. Goes in a [FlutterMap]'s children,
/// below the markers.
class BaseMapLayer extends ConsumerStatefulWidget {
  const BaseMapLayer({super.key});

  @override
  ConsumerState<BaseMapLayer> createState() => _BaseMapLayerState();
}

class _BaseMapLayerState extends ConsumerState<BaseMapLayer> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Le style n'a pas pu être lu (lancement hors ligne, par exemple) :
    // nouvel essai au retour dans l'app, plutôt qu'une carte vide jusqu'au
    // prochain redémarrage.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (ref.read(mapStyleProvider).hasError) {
          ref.invalidate(mapStyleProvider);
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.usesVectorMap) {
      return TileLayer(
        urlTemplate: AppConfig.tileUrlTemplate,
        userAgentPackageName: AppConfig.packageName,
      );
    }
    final style = ref.watch(mapStyleProvider).valueOrNull;
    if (style == null) return const SizedBox.shrink();
    return VectorTileLayer(
      theme: style.theme,
      sprites: style.sprites,
      tileProviders: style.providers,
    );
  }
}
