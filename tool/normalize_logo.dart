// Met une image d'enseigne au format du projet : carré de 256 px, fond blanc,
// dessin détouré puis recentré avec une marge constante.
//
//   flutter test tool/normalize_logo.dart
//
// Prend tout ce qui traîne dans tool/icons_recuperees/ (voir
// tool/fetch_brand_icons.dart et tool/search_commons_logos.dart) et écrit
// assets/logos/<clé>.png. La clé est le nom du fichier avant le premier « _ ».
//
// Détourer est le cœur de l'affaire : une icône téléchargée arrive souvent
// avec une marge transparente généreuse, qui ferait passer le dessin sous le
// seuil de lisibilité de [BrandLogo] alors que le logo lui-même est bon.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Côté des logos embarqués, comme le veut assets/logos/LISEZMOI.txt.
const _side = 256;

/// Part du carré occupée par le dessin. Les logos existants tournent entre
/// 90 et 100 % ; en dessous, le symbole flotte et paraît plus petit que ses
/// voisins sur la carte.
const _contentFraction = 0.94;

/// Au-delà de cet écart au blanc, un pixel compte comme du dessin.
const _whiteTolerance = 12;

void main() {
  testWidgets('normalise les logos récupérés', (tester) async {
    await tester.runAsync(() async {
      final inDir = Directory('tool/icons_recuperees');
      if (!inDir.existsSync()) {
        debugPrint('Rien à normaliser : ${inDir.path} absent.');
        return;
      }

      for (final file in inDir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.png'),
      )) {
        final key = file.uri.pathSegments.last.split(RegExp(r'[_.]')).first;
        final bytes = await _normalize(file);
        if (bytes == null) {
          debugPrint('$key : image vide, ignorée');
          continue;
        }
        File('assets/logos/$key.png').writeAsBytesSync(bytes);
        debugPrint('$key : écrit assets/logos/$key.png (${bytes.length} o)');
      }
    });
  });
}

Future<Uint8List?> _normalize(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  final source = (await codec.getNextFrame()).image;
  final raw = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
  final bounds = _contentBounds(
    raw!.buffer.asUint8List(),
    source.width,
    source.height,
  );
  if (bounds == null) {
    source.dispose();
    codec.dispose();
    return null;
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // Fond blanc : les logos sont posés sur des pastilles blanches, et une
  // transparence résiduelle ferait apparaître la carte au travers.
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _side * 1.0, _side * 1.0),
    Paint()..color = Colors.white,
  );

  final scale = _side * _contentFraction / bounds.longestSide;
  final width = bounds.width * scale;
  final height = bounds.height * scale;
  canvas.drawImageRect(
    source,
    bounds,
    Rect.fromLTWH((_side - width) / 2, (_side - height) / 2, width, height),
    Paint()..filterQuality = FilterQuality.high,
  );

  final picture = recorder.endRecording();
  final output = await picture.toImage(_side, _side);
  final png = await output.toByteData(format: ui.ImageByteFormat.png);

  source.dispose();
  codec.dispose();
  picture.dispose();
  output.dispose();
  return png!.buffer.asUint8List();
}

/// Rectangle réellement dessiné, hors marge blanche ou transparente.
Rect? _contentBounds(Uint8List pixels, int width, int height) {
  var left = width;
  var top = height;
  var right = -1;
  var bottom = -1;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      if (pixels[i + 3] < 8) continue;
      final isInk =
          255 - pixels[i] > _whiteTolerance ||
          255 - pixels[i + 1] > _whiteTolerance ||
          255 - pixels[i + 2] > _whiteTolerance;
      if (!isInk) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }

  if (right < 0) return null;
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right + 1.0,
    bottom + 1.0,
  );
}
