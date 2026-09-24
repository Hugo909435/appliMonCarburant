import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/features/home/widgets/sync_indicator.dart';
import 'package:mon_carburant_app/providers/stations_provider.dart';

Future<void> _pump(WidgetTester tester, StationsSync sync) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [stationsSyncProvider.overrideWith((ref) => sync)],
      child: const MaterialApp(home: Scaffold(body: SyncIndicator())),
    ),
  );
}

void main() {
  testWidgets('rien n’est affiché quand les prix sont à jour', (tester) async {
    await _pump(tester, StationsSync.idle);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('mise à jour en cours : libellé et explication', (tester) async {
    await _pump(tester, StationsSync.updating);
    expect(find.text('Mise à jour des prix…'), findsOneWidget);

    await tester.tap(find.text('Mise à jour des prix…'));
    await tester.pump();
    expect(
      find.textContaining('Téléchargement des derniers prix'),
      findsOneWidget,
    );
  });

  testWidgets('hors ligne : explique la mise à jour au retour du réseau', (
    tester,
  ) async {
    await _pump(tester, StationsSync.offline);
    await tester.tap(find.text('Hors ligne'));
    await tester.pump();
    expect(find.textContaining('Pas de connexion internet'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('échec : propose de réessayer', (tester) async {
    await _pump(tester, StationsSync.failed);
    await tester.tap(find.text('Prix non mis à jour'));
    await tester.pump();
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
