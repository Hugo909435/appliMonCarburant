import 'package:cloud_firestore/cloud_firestore.dart';

import 'favorites_service.dart';

/// One document per user (`users/{uid}`) holding a single
/// `favoriteStationIds` array — a direct match for the `Set<String>` model
/// used throughout the app, and cheaper than a subcollection for a list of
/// this size (one read + one write per toggle).
class FirestoreFavoritesService implements FavoritesService {
  FirestoreFavoritesService(this.uid);

  final String uid;

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  @override
  Future<Set<String>> load() async {
    final snap = await _doc.get();
    return ((snap.data()?['favoriteStationIds'] as List?) ?? const [])
        .cast<String>()
        .toSet();
  }

  @override
  Future<void> save(Set<String> ids) {
    return _doc.set({
      'favoriteStationIds': ids.toList(),
    }, SetOptions(merge: true));
  }
}
