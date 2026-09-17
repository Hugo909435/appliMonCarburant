import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Station ids picked for side-by-side comparison, capped at 2. Selecting a
/// third replaces the oldest pick (rolling window) rather than blocking.
class ComparisonNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void toggle(String stationId) {
    if (state.contains(stationId)) {
      state = state.where((id) => id != stationId).toList();
      return;
    }
    if (state.length >= 2) {
      state = [state.last, stationId];
      return;
    }
    state = [...state, stationId];
  }

  void clear() => state = const [];
}

final comparisonProvider = NotifierProvider<ComparisonNotifier, List<String>>(
  ComparisonNotifier.new,
);
