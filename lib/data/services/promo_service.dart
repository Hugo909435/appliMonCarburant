import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/promo_annonce.dart';

/// Source de l'annonce « prix coûtant » : un document unique
/// `config/prix_coutant` dans Firestore.
///
/// Un document plutôt qu'une collection : il n'y a jamais qu'une opération
/// mise en avant à la fois, et ça se modifie en trente secondes depuis la
/// console Firebase — c'est tout l'intérêt, aucune mise à jour de l'app
/// n'est nécessaire pour allumer ou éteindre le bandeau.
///
/// L'écoute est temps réel (`snapshots`) : une annonce publiée pendant
/// qu'une app est ouverte apparaît sans redémarrage, et le cache hors ligne
/// de Firestore ressert la dernière valeur connue quand le réseau manque.
class PromoService {
  static const docPath = 'config/prix_coutant';

  Stream<PromoAnnonce?> watch() {
    return FirebaseFirestore.instance
        .doc(docPath)
        .snapshots()
        .map((snap) => PromoAnnonce.fromMap(_normalize(snap.data())))
        .handleError((Object e) {
          // Document absent, règles refusées, offline au premier lancement :
          // une annonce est du bonus, elle ne doit jamais remonter d'erreur
          // à l'utilisateur.
          debugPrint('Annonce prix coûtant indisponible: $e');
        });
  }

  /// Convertit les `Timestamp` Firestore en `DateTime` pour que le modèle
  /// reste indépendant du SDK (et testable sans Firebase).
  static Map<String, dynamic>? _normalize(Map<String, dynamic>? data) {
    if (data == null) return null;
    return data.map(
      (key, value) =>
          MapEntry(key, value is Timestamp ? value.toDate() : value),
    );
  }
}
