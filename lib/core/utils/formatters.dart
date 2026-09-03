String formatPrice(double? price) {
  if (price == null) return '—';
  return '${price.toStringAsFixed(3).replaceFirst('.', ',')} €';
}

String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(1).replaceFirst('.', ',')} km';
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
