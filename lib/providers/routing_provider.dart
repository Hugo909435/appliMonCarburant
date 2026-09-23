import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/routing_service.dart';

/// Injecté plutôt qu'instancié dans l'écran : le serveur de routage change
/// d'une configuration de build à l'autre (voir [AppConfig]), et un test doit
/// pouvoir substituer le service sans appeler le réseau.
final routingServiceProvider = Provider<RoutingService>(
  (ref) => RoutingService(),
);
