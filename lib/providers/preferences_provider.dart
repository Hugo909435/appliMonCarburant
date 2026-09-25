import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences chargées une fois dans `main()`, avant le premier écran,
/// pour les réglages qu'il faut connaître sans attendre : faut-il montrer
/// l'accueil, quel carburant afficher sur la carte.
///
/// Null quand rien ne les fournit (tests, aperçus de widgets) : chaque
/// lecteur retombe alors sur sa valeur par défaut.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);
