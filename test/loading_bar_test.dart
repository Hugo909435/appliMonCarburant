import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_carburant_app/shared/widgets/loading_bar.dart';

void main() {
  double fillWidth(WidgetTester tester) => tester
      .getSize(
        find
            .descendant(
              of: find.byType(Align),
              matching: find.byType(Container),
            )
            .first,
      )
      .width;

  testWidgets('la barre grandit puis se rétracte, en boucle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: LoadingBar(label: 'Recherche des bornes…')),
        ),
      ),
    );
    expect(fillWidth(tester), 0);

    await tester.pump(const Duration(milliseconds: 500));
    expect(fillWidth(tester), closeTo(130, 0.5));

    await tester.pump(const Duration(milliseconds: 250));
    expect(fillWidth(tester), closeTo(65, 0.5));

    expect(find.text('Recherche des bornes…'), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('animations coupées : une barre fixe', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Scaffold(body: Center(child: LoadingBar()))),
      ),
    );

    expect(tester.hasRunningAnimations, isFalse);
  });
}
