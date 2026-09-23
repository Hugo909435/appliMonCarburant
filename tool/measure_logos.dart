// Mesure la place réellement occupée par le dessin dans chaque logo
// d'enseigne, et écrit le résultat dans lib/core/brands/logo_metrics.dart.
//
//   flutter test tool/measure_logos.dart
//
// À relancer après tout ajout ou remplacement dans assets/logos/.
//
// Pourquoi : les fichiers sont des carrés de 256 px, mais certains logos sont
// des logotypes larges (« E.Leclerc », « SPAR ») qui n'occupent qu'une mince
// bande horizontale. `BoxFit.contain` ajuste le carré entier, pas le dessin :
// à 22 px sur la carte, la bande tombe à 3 ou 4 px de haut et le nom devient
// illisible. [BrandLogo] se sert de cette mesure pour basculer sur le badge
// coloré, lisible, dans ces cas-là.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un pixel est considéré comme du dessin dès qu'il s'écarte du blanc de plus
/// de ce seuil, ce qui ignore le lissage des bords et les fonds « presque
/// blancs » des exports.
const _whiteTolerance = 12;

void main() {
  testWidgets('mesure les logos d\'enseignes', (tester) async {
    await tester.runAsync(() async {
      final dir = Directory('assets/logos');
      final files =
          dir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.png'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final fractions = <String, double>{};
      for (final file in files) {
        final key = file.uri.pathSegments.last.replaceAll('.png', '');
        fractions[key] = await _contentHeightFraction(file);
      }

      File('lib/core/brands/logo_metrics.dart')
          .writeAsStringSync(_render(fractions));
      fractions.forEach(
        (key, value) => debugPrint(
          '$key : ${(value * 100).toStringAsFixed(0)} % de hauteur',
        ),
      );
    });
  });
}

/// Hauteur du dessin rapportée à celle de l'image, entre 0 et 1.
Future<double> _contentHeightFraction(File file) async {
  final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = data!.buffer.asUint8List();
  final width = image.width;
  final height = image.height;

  var top = -1;
  var bottom = -1;
  for (var y = 0; y < height; y++) {
    if (_rowHasContent(pixels, y, width)) {
      top = top == -1 ? y : top;
      bottom = y;
    }
  }
  image.dispose();
  codec.dispose();

  if (top == -1) return 0;
  return (bottom - top + 1) / height;
}

bool _rowHasContent(Uint8List pixels, int y, int width) {
  for (var x = 0; x < width; x++) {
    final i = (y * width + x) * 4;
    final a = pixels[i + 3];
    if (a < 8) continue; // transparent : pas du dessin
    // Un pixel opaque et suffisamment éloigné du blanc.
    if (255 - pixels[i] > _whiteTolerance ||
        255 - pixels[i + 1] > _whiteTolerance ||
        255 - pixels[i + 2] > _whiteTolerance) {
      return true;
    }
  }
  return false;
}

String _render(Map<String, double> fractions) {
  final buffer = StringBuffer()
    ..writeln(
      '// GÉNÉRÉ par tool/measure_logos.dart — ne pas modifier à la main.',
    )
    ..writeln('//')
    ..writeln('//   flutter test tool/measure_logos.dart')
    ..writeln('//')
    ..writeln(
      '// Part du fichier réellement occupée par le dessin, en hauteur. Les',
    )
    ..writeln(
      '// logotypes larges tombent bas ; voir [BrandLogo] pour ce qui en est',
    )
    ..writeln('// fait.')
    ..writeln()
    ..writeln('const logoContentHeightFraction = <String, double>{');
  for (final entry in fractions.entries) {
    buffer.writeln("  '${entry.key}': ${entry.value.toStringAsFixed(3)},");
  }
  buffer.writeln('};');
  return buffer.toString();
}
