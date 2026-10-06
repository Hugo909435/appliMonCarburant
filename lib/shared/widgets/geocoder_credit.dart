import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

/// The "Search by LocationIQ.com" link LocationIQ's free plan requires next
/// to address results. Nothing when another geocoder is configured.
class GeocoderCredit extends StatelessWidget {
  const GeocoderCredit({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.usesLocationIq) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: color,
      decoration: TextDecoration.underline,
      decorationColor: color,
    );
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () => launchUrl(
          Uri.parse('https://locationiq.com'),
          mode: LaunchMode.externalApplication,
        ),
        child: Text('Search by LocationIQ.com', style: style),
      ),
    );
  }
}
