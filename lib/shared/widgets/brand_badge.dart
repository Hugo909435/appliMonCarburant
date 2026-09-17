import 'package:flutter/material.dart';

/// A small circular badge standing in for a station's brand logo: a
/// deterministic color (hashed from the brand name) and its initial letter.
/// Deliberately generic rather than a scraped/trademarked logo image.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.brand, this.size = 22});

  final String brand;
  final double size;

  static const _palette = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFF3949AB),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
    Color(0xFF546E7A),
  ];

  Color get _color => _palette[brand.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final letter = brand.trim().isEmpty ? '?' : brand.trim()[0].toUpperCase();
    return Tooltip(
      message: brand,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}
