import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/stats_provider.dart';
import '../../shared/widgets/station_list_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.title, required this.query});

  final String title;
  final GroupQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(groupStationsProvider(query));
    final stats = ref.watch(groupStatsProvider(query));

    return StationListScreen(
      title: title,
      stations: stations,
      stats: stats,
    );
  }
}
