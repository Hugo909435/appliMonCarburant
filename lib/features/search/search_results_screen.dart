import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/derived_providers.dart';
import '../../shared/widgets/station_list_screen.dart';

class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider(query));
    return StationListScreen(
      title: 'Résultats pour « $query »',
      stations: results,
      emptyMessage: 'Aucune station ne correspond à « $query ».',
    );
  }
}
