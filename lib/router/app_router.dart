import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/compare/compare_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/groups/autoroutes_list_screen.dart';
import '../features/groups/departments_list_screen.dart';
import '../features/groups/group_detail_screen.dart';
import '../features/groups/regions_list_screen.dart';
import '../features/home/home_screen.dart';
import '../features/national/national_price_screen.dart';
import '../features/nearby/nearby_screen.dart';
import '../features/privacy/privacy_screen.dart';
import '../features/route/route_screen.dart';
import '../features/search/search_results_screen.dart';
import '../features/station_detail/station_detail_screen.dart';
import '../features/vehicle/vehicle_screen.dart';
import '../providers/stats_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Pas de barre d'onglets : la carte occupe tout l'écran et porte
    // elle-même ses boutons (favoris, trajet, compte…), qui poussent leur
    // écran par-dessus.
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/favoris',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/compte',
      builder: (context, state) => const AccountScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/vehicule',
      builder: (context, state) => const VehicleScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/confidentialite',
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/trajet',
      builder: (context, state) => const RouteScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/pres-de-moi',
      builder: (context, state) => const NearbyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/national',
      builder: (context, state) => const NationalPriceScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/comparer',
      builder: (context, state) => const CompareScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/search',
      builder: (context, state) =>
          SearchResultsScreen(query: state.uri.queryParameters['q'] ?? ''),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/station/:id',
      builder: (context, state) =>
          StationDetailScreen(stationId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/departements',
      builder: (context, state) => const DepartmentsListScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/departement/:num',
      builder: (context, state) {
        final num = state.pathParameters['num']!;
        final title = state.extra as String? ?? 'Département $num';
        return GroupDetailScreen(
          title: title,
          query: GroupQuery(GroupType.department, num),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/regions',
      builder: (context, state) => const RegionsListScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/region/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        final title = state.extra as String? ?? slug;
        return GroupDetailScreen(
          title: title,
          query: GroupQuery(GroupType.region, slug),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/autoroutes',
      builder: (context, state) => const AutoroutesListScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/autoroute/:code',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        return GroupDetailScreen(
          title: 'Autoroute $code',
          query: GroupQuery(GroupType.autoroute, code),
        );
      },
    ),
  ],
);
