import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';

/// The recurring visual signature of the app: a small dark "sign plate"
/// with bold tabular digits, echoing the roadside price totems outside
/// every French filling station.
enum PriceTotemSize { compact, large, giant }

class PriceTotem extends StatelessWidget {
  const PriceTotem({
    super.key,
    required this.price,
    this.size = PriceTotemSize.compact,
    this.accentColor,
    this.inverted = false,
  });

  final double? price;
  final PriceTotemSize size;
  final Color? accentColor;

  /// Light "sign plate" on a dark surface instead of the usual dark plate,
  /// for placement directly on the navy hero.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final formatted = formatPrice(price);
    final spaceIndex = formatted.indexOf(' ');
    final number = spaceIndex == -1
        ? formatted
        : formatted.substring(0, spaceIndex);
    final unit = spaceIndex == -1 ? '' : formatted.substring(spaceIndex + 1);
    final plate = inverted ? AppColors.surfaceLight : AppColors.primary;
    final numberColor = inverted ? AppColors.primary : Colors.white;
    final unitColor = inverted
        ? AppColors.primary.withValues(alpha: 0.6)
        : Colors.white70;

    final (
      hPad,
      vPad,
      radius,
      borderWidth,
      numberSize,
      unitSize,
    ) = switch (size) {
      PriceTotemSize.compact => (12.0, 7.0, AppRadius.sm, 4.0, 17.0, 10.5),
      PriceTotemSize.large => (18.0, 12.0, AppRadius.md, 6.0, 32.0, 15.0),
      PriceTotemSize.giant => (26.0, 18.0, AppRadius.lg, 9.0, 56.0, 19.0),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: plate,
        borderRadius: BorderRadius.circular(radius),
        border: Border(
          left: BorderSide(
            color: accentColor ?? AppColors.accent,
            width: borderWidth,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            number,
            style: GoogleFonts.archivoBlack(
              color: numberColor,
              fontSize: numberSize,
              height: 1,
              letterSpacing: -0.3,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              unit,
              style: GoogleFonts.archivo(
                color: unitColor,
                fontSize: unitSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stand-in for [PriceTotem] at a station with no fuel on sale: the same
/// plate, greyed out, reading "En rupture" instead of a price.
class OutOfStockTotem extends StatelessWidget {
  const OutOfStockTotem({super.key, this.size = PriceTotemSize.compact});

  final PriceTotemSize size;

  /// Plate colour, also used for the map dot of such a station.
  static const color = Color(0xFF8A949B);

  @override
  Widget build(BuildContext context) {
    final (hPad, vPad, radius, fontSize) = switch (size) {
      PriceTotemSize.compact => (10.0, 8.0, AppRadius.sm, 12.5),
      PriceTotemSize.large => (16.0, 13.0, AppRadius.md, 20.0),
      PriceTotemSize.giant => (22.0, 19.0, AppRadius.lg, 32.0),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        'En rupture',
        style: GoogleFonts.archivo(
          color: Colors.white,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
