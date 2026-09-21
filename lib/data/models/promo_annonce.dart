/// Annonce « prix coûtant » pilotée à distance : elle vit dans Firestore,
/// pas dans le binaire, pour pouvoir signaler une opération en cours (ou
/// l'arrêter) sans republier l'application sur les stores.
class PromoAnnonce {
  const PromoAnnonce({
    required this.id,
    required this.titre,
    required this.message,
    required this.actif,
    this.debut,
    this.fin,
    this.lienUrl,
    this.lienLibelle,
  });

  /// Identifiant de campagne. C'est lui qui sert de clé au « déjà fermée » :
  /// changer l'id fait réapparaître le bandeau une fois, y compris chez les
  /// utilisateurs qui avaient fermé l'annonce précédente. Le réutiliser, au
  /// contraire, respecte leur choix.
  final String id;

  final String titre;
  final String message;
  final bool actif;

  /// Fenêtre d'affichage optionnelle. La renseigner évite d'avoir à penser
  /// à rebasculer `actif` à false une fois l'opération terminée.
  final DateTime? debut;
  final DateTime? fin;

  /// Lien optionnel (page de l'enseigne, article...). Sans lien, le bandeau
  /// est purement informatif et non cliquable.
  final String? lienUrl;
  final String? lienLibelle;

  bool get hasLien => (lienUrl ?? '').trim().isNotEmpty;

  bool isLiveAt(DateTime now) {
    if (!actif) return false;
    if (id.isEmpty || message.trim().isEmpty) return false;
    if (debut != null && now.isBefore(debut!)) return false;
    if (fin != null && now.isAfter(fin!)) return false;
    return true;
  }

  /// Tolérante par construction : la doc est éditée à la main dans la console
  /// Firebase, une faute de frappe ou un champ oublié doit se traduire par
  /// « pas d'annonce », jamais par un crash.
  static PromoAnnonce? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final id = (data['id'] as String?)?.trim() ?? '';
    final message = (data['message'] as String?)?.trim() ?? '';
    if (id.isEmpty || message.isEmpty) return null;
    return PromoAnnonce(
      id: id,
      titre: (data['titre'] as String?)?.trim() ?? 'Opération prix coûtant',
      message: message,
      actif: data['actif'] == true,
      debut: _parseDate(data['debut']),
      fin: _parseDate(data['fin']),
      lienUrl: (data['lienUrl'] as String?)?.trim(),
      lienLibelle: (data['lienLibelle'] as String?)?.trim(),
    );
  }

  /// Accepte aussi bien un champ Date de la console (converti en [DateTime]
  /// en amont par le service) qu'une chaîne ISO tapée à la main.
  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
