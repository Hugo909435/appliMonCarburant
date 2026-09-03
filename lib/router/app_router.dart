import 'package:go_router/go_router.dart';

import '../features/favorites/favorites_screen.dart';
import '../features/groups/autoroutes_list_screen.dart';
import '../features/groups/departments_list_screen.dart';
import '../features/groups/group_detail_screen.dart';
import '../features/groups/regions_list_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/national/national_price_screen.dart';
import '../features/nearby/nearby_screen.dart';
import '../features/search/search_results_screen.dart';
import '../features/station_detail/station_detail_screen.dart';
import '../providers/stats_provider.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/carte', builder: (context, state) => const MapScreen()),
    GoRoute(path: '/pres-de-moi', builder: (context, state) => const NearbyScreen()),
    GoRoute(path: '/favoris', builder: (context, state) => const FavoritesScreen()),
    GoRoute(path: '/national', builder: (context, state) => const NationalPriceScreen()),
    GoRoute(
      path: '/search',
      builder: (context, state) =>
          SearchResultsScreen(query: state.uri.queryParameters['q'] ?? ''),
    ),
    GoRoute(
      path: '/station/:id',
      builder: (context, state) =>
          StationDetailScreen(stationId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/departements', builder: (context, state) => const DepartmentsListScreen()),
    GoRoute(
      path: '/departement/:num',
      builder: (context, state) {
        final num = state.pathParameters['num']!;
        final title = state.extra as String? ?? 'Département $num';
        return GroupDetailScreen(title: title, query: GroupQuery(GroupType.department, num));
      },
    ),
    GoRoute(path: '/regions', builder: (context, state) => const RegionsListScreen()),
    GoRoute(
      path: '/region/:slug',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        final title = state.extra as String? ?? slug;
        return GroupDetailScreen(title: title, query: GroupQuery(GroupType.region, slug));
      },
    ),
    GoRoute(path: '/autoroutes', builder: (context, state) => const AutoroutesListScreen()),
    GoRoute(
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
