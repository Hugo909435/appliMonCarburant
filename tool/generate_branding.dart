// Génère les sources de la marque (icône d'app + logos de démarrage) à partir
// du seul dessin vectoriel ci-dessous, pour qu'il n'y ait jamais deux versions
// du logo qui divergent.
//
//   flutter test tool/generate_branding.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create
//
// Les fichiers produits vont dans assets/branding/ : ce sont des *sources de
// build*, volontairement absentes de la section `assets:` du pubspec — elles
// n'ont pas à être embarquées dans l'app.
//
// Le dessin suit la charte (core/theme/app_theme.dart) : monochrome, noir et
// blanc, aucune couleur d'enseigne. Le glyphe est une pompe dont l'afficheur
// et les deux lignes de prix sont détourés — l'app compare des prix, l'icône
// le dit.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Encombrement réel du glyphe, socle et pistolet compris, dans le repère où
/// sont exprimées toutes les coordonnées du dessin. Sert à le recentrer :
/// c'est ce rectangle, et non le repère, qui est aligné sur le centre de
/// chaque image produite.
const _glyphBounds = Rect.fromLTRB(204, 196, 768, 812);

/// Noir de la charte (AppColors.primary).
const _ink = Color(0xFF111111);

void main() {
  testWidgets('génère les assets de marque', (tester) async {
    // runAsync : hors de lui, `testWidgets` remplace l'horloge par un faux
    // temps et les Future réellement asynchrones de `Picture.toImage` ne se
    // résolvent jamais.
    await tester.runAsync(() async {
      Directory('assets/branding').createSync(recursive: true);

      // Icône d'app : glyphe blanc sur fond noir, plein cadre — iOS arrondit
      // lui-même les angles et refuse toute transparence sur le 1024.
      await _write('assets/branding/app_icon.png', 1024, (canvas, size) {
        _paintBackground(canvas, size);
        _paintGlyph(canvas, size, Colors.white, heightFraction: 0.58);
      });

      // Calque avant des icônes adaptatives Android : le glyphe seul, très
      // en retrait — le masque du système peut rogner jusqu'au tiers de
      // l'image, et l'animation de lancement la met à l'échelle.
      await _write('assets/branding/app_icon_foreground.png', 1024, (
        canvas,
        size,
      ) {
        _paintGlyph(canvas, size, Colors.white, heightFraction: 0.40);
      });

      // Logos de l'écran de démarrage, sur fond transparent : un par thème.
      await _write('assets/branding/splash_logo_light.png', 768, (
        canvas,
        size,
      ) {
        _paintGlyph(canvas, size, _ink, heightFraction: 0.92);
      });
      await _write('assets/branding/splash_logo_dark.png', 768, (canvas, size) {
        _paintGlyph(canvas, size, Colors.white, heightFraction: 0.92);
      });

      // Android 12+ impose son gabarit : image de 1152 px dont seul un disque
      // central de 768 px est visible. Le glyphe doit donc y tenir largement
      // au large, sans quoi le système le rogne.
      await _write('assets/branding/splash_logo_light_android12.png', 1152, (
        canvas,
        size,
      ) {
        _paintGlyph(canvas, size, _ink, heightFraction: 0.46);
      });
      await _write('assets/branding/splash_logo_dark_android12.png', 1152, (
        canvas,
        size,
      ) {
        _paintGlyph(canvas, size, Colors.white, heightFraction: 0.46);
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

void _paintBackground(Canvas canvas, double size) {
  final rect = Rect.fromLTWH(0, 0, size, size);
  // Dégradé très léger : sur un aplat parfaitement noir, l'icône paraît plate
  // au milieu d'un fond d'écran sombre.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF242424), Color(0xFF060606)],
      ).createShader(rect),
  );
}

/// Dessine la pompe, recentrée dans un carré de [size] pixels, à une échelle
/// telle que sa hauteur occupe [heightFraction] du côté.
void _paintGlyph(
  Canvas canvas,
  double size,
  Color color, {
  required double heightFraction,
}) {
  canvas.save();
  canvas.translate(size / 2, size / 2);
  canvas.scale(size * heightFraction / _glyphBounds.height);
  canvas.translate(-_glyphBounds.center.dx, -_glyphBounds.center.dy);

  final body = Path()
    ..addRRect(
      RRect.fromLTRBAndCorners(
        248,
        196,
        596,
        812,
        topLeft: const Radius.circular(58),
        topRight: const Radius.circular(58),
        bottomLeft: const Radius.circular(18),
        bottomRight: const Radius.circular(18),
      ),
    );

  // Socle : déborde de la caisse des deux côtés, comme une pompe posée au sol.
  final base = Path()
    ..addRRect(
      RRect.fromLTRBR(204, 754, 640, 812, const Radius.circular(22)),
    );

  // L'afficheur et les deux lignes de prix sont retranchés de la caisse : un
  // trou laisse passer le fond, ce qui garde le logo lisible posé sur
  // n'importe quelle couleur.
  final cutouts = Path()
    ..addRRect(
      RRect.fromLTRBR(316, 272, 528, 430, const Radius.circular(26)),
    )
    ..addRRect(
      RRect.fromLTRBR(316, 506, 528, 548, const Radius.circular(21)),
    )
    ..addRRect(
      RRect.fromLTRBR(316, 592, 452, 634, const Radius.circular(21)),
    );

  canvas.drawPath(
    Path.combine(
      PathOperation.difference,
      Path.combine(PathOperation.union, body, base),
      cutouts,
    ),
    Paint()
      ..color = color
      ..isAntiAlias = true,
  );

  // Le flexible sort du flanc de la pompe, remonte et s'incurve vers le
  // pistolet. Tracé au trait plutôt qu'uni à la caisse : `Path.combine`
  // n'opère que sur des surfaces fermées, et rien ne vient l'évider.
  canvas.drawPath(
    Path()
      ..moveTo(584, 610)
      ..lineTo(660, 610)
      ..quadraticBezierTo(704, 610, 704, 566)
      ..lineTo(704, 392)
      ..quadraticBezierTo(704, 348, 746, 336),
    Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 44
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.restore();
}
