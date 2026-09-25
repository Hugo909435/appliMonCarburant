String formatPrice(double? price) {
  if (price == null) return '—';
  return '${price.toStringAsFixed(3).replaceFirst('.', ',')} €';
}

String formatEuros(double amount) =>
    '${amount.toStringAsFixed(2).replaceFirst('.', ',')} €';

/// Écart de prix au litre, toujours signé : « +0,043 € ». Le signe est ce
/// qui distingue un écart d'un prix, et il ne doit jamais disparaître.
String formatPriceGap(double delta) {
  final sign = delta < 0 ? '−' : '+';
  return '$sign${delta.abs().toStringAsFixed(3).replaceFirst('.', ',')} €';
}

String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1).replaceFirst('.', ',')} km';
}

/// Temps de trajet estimé : « 1 min », « 12 min », « 1 h 05 ». Arrondi à la
/// minute supérieure, et jamais « 0 min » pour une station à deux pas.
String formatDriveTime(Duration duration) {
  final totalMinutes = (duration.inSeconds / 60).ceil().clamp(1, 1 << 30);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes min';
  return '$hours h ${minutes.toString().padLeft(2, '0')}';
}

String formatRelativeDate(DateTime? date) {
  if (date == null) return 'Date inconnue';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

String dayLabel(int index) => _dayLabels[index];

String formatHoursSlot(String? raw) {
  if (raw == null) return 'Fermé';
  if (raw == 'F') return 'Fermé';
  return raw.split(',').join(' / ');
}
