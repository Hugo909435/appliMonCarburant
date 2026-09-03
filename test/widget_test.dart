import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_carburant_app/app.dart';

void main() {
  testWidgets('App boots to the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MonCarburantApp()));
    await tester.pump();

    expect(find.text('Mon Carburant'), findsWidgets);
  });
}
