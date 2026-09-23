import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/app.dart';
import 'package:mon_carburant_app/features/home/home_screen.dart';

void main() {
  testWidgets('App boots to the map home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MonCarburantApp()));
    await tester.pump();

    // Le titre textuel a disparu avec le passage à un accueil carte-first :
    // ce qui compte désormais est que le routeur démarre bien sur la carte,
    // sans exception au premier frame.
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
