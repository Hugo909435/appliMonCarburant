// Génère les sources de la marque (icône d'app + logos de démarrage) à partir
// du seul logo vectoriel assets/branding/logo.svg — le même fichier que le
// favicon du site — pour qu'il n'y ait jamais deux versions du logo qui
// divergent.
//
//   flutter test tool/generate_branding.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Les fichiers produits vont dans assets/branding/ : ce sont des *sources de
// build*, volontairement absentes de la section `assets:` du pubspec — elles
// n'ont pas à être embarquées dans l'app.
//
// Le SVG est une tuile bleu nuit (un <rect>) portant une pompe blanche, une
// flamme et un bandeau orange. Seules les commandes absolues M, C et Z sont
// lues : c'est tout ce que le fichier emploie.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _source = 'assets/branding/logo.svg';

void main() {
  testWidgets('génère les assets de marque', (tester) async {
    // runAsync : hors de lui, `testWidgets` remplace l'horloge par un faux
    // temps et les Future réellement asynchrones de `Picture.toImage` ne se
    // résolvent jamais.
    await tester.runAsync(() async {
      final logo = _Logo.parse(File(_source).readAsStringSync());

      // Icône d'app : le glyphe sur la tuile, plein cadre — iOS arrondit
      // lui-même les angles et refuse toute transparence sur le 1024.
      await _write('assets/branding/app_icon.png', 1024, (canvas, size) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size, size),
          Paint()..color = logo.background,
        );
        logo.paint(canvas, size, heightFraction: 0.64);
      });

      // Calque avant des icônes adaptatives Android : le glyphe seul, très
      // en retrait — le masque du système peut rogner jusqu'au tiers de
      // l'image, et l'animation de lancement la met à l'échelle. Les
      // évidements laissent voir le fond (adaptive_icon_background).
      await _write('assets/branding/app_icon_foreground.png', 1024, (
        canvas,
        size,
      ) {
        logo.paint(canvas, size, heightFraction: 0.48);
      });

      // Icône monochrome des thèmes dynamiques d'Android 13+ : seul l'alpha
      // compte, la flamme et le bandeau passent donc en blanc eux aussi.
      await _write('assets/branding/app_icon_monochrome.png', 1024, (
        canvas,
        size,
      ) {
        logo.paint(canvas, size, heightFraction: 0.48, tint: Colors.white);
      });

      // Logo de l'écran de démarrage, posé sur le bleu de la tuile (voir
      // flutter_native_splash dans le pubspec), identique en clair et sombre.
      await _write('assets/branding/splash_logo.png', 768, (canvas, size) {
        logo.paint(canvas, size, heightFraction: 0.92);
      });

      // Android 12+ impose son gabarit : image de 1152 px dont seul un disque
      // central de 768 px est visible. Le glyphe doit donc y tenir largement
      // au large, sans quoi le système le rogne.
      await _write('assets/branding/splash_logo_android12.png', 1152, (
        canvas,
        size,
      ) {
        logo.paint(canvas, size, heightFraction: 0.46);
      });

      for (final file
          in Directory('assets/branding').listSync().whereType<File>()) {
        debugPrint('écrit ${file.path} (${file.lengthSync()} octets)');
      }
    });
  });
}

/// Rend [paint] dans un carré de [size] pixels et l'écrit en PNG.
Future<void> _write(
  String path,
  int size,
  void Function(Canvas canvas, double size) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, size.toDouble());
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

/// Le logo lu depuis le SVG : la couleur de la tuile et les tracés colorés
/// posés dessus, dans l'ordre du fichier.
class _Logo {
  _Logo(this.background, this.layers)
    : bounds = layers
          .map((l) => l.path.getBounds())
          .reduce((a, b) => a.expandToInclude(b));

  factory _Logo.parse(String svg) {
    final rectFill = RegExp(r'<rect[^>]*fill="([^"]+)"').firstMatch(svg)!;
    final layers = [
      for (final m in RegExp(
        r'<path\s+d="([^"]+)"\s+fill="([^"]+)"',
      ).allMatches(svg))
        (path: _parsePath(m[1]!), color: _parseColor(m[2]!)),
    ];
    return _Logo(_parseColor(rectFill[1]!), layers);
  }

  final Color background;
  final List<({Path path, Color color})> layers;

  /// Encombrement réel du glyphe, tuile exclue : c'est lui, et non le
  /// viewBox, qui est centré dans chaque image produite.
  final Rect bounds;

  /// Dessine le glyphe centré dans un carré de [size] pixels, à une échelle
  /// telle que sa hauteur occupe [heightFraction] du côté. [tint] remplace
  /// toutes les couleurs.
  void paint(
    Canvas canvas,
    double size, {
    required double heightFraction,
    Color? tint,
  }) {
    canvas.save();
    canvas.translate(size / 2, size / 2);
    canvas.scale(size * heightFraction / bounds.height);
    canvas.translate(-bounds.center.dx, -bounds.center.dy);
    for (final layer in layers) {
      canvas.drawPath(
        layer.path,
        Paint()
          ..color = tint ?? layer.color
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
  }
}

Path _parsePath(String d) {
  final tokens = RegExp(
    r'[MCZ]|-?\d*\.?\d+',
  ).allMatches(d).map((m) => m[0]!).toList();
  final path = Path()..fillType = PathFillType.evenOdd;
  var i = 0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    switch (tokens[i++]) {
      case 'M':
        path.moveTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      case 'Z':
        path.close();
      case final t:
        throw FormatException('Commande SVG non gérée : $t');
    }
  }
  return path;
}

Color _parseColor(String value) {
  final rgb = RegExp(r'rgb\((\d+),\s*(\d+),\s*(\d+)\)').firstMatch(value);
  if (rgb != null) {
    return Color.fromARGB(
      255,
      int.parse(rgb[1]!),
      int.parse(rgb[2]!),
      int.parse(rgb[3]!),
    );
  }
  return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
}
