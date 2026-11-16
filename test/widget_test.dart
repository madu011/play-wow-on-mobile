import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('WOW LK launcher renders its main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AzerothApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('WOW LK'), findsOneWidget);
    expect(find.text('Automatic hardware scan'), findsOneWidget);
    expect(find.text('GAME'), findsOneWidget);
    expect(find.text('REALMS'), findsOneWidget);
    expect(find.text('OPTIONS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SELECT WOW GAME FOLDER'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SELECT WOW GAME FOLDER'), findsOneWidget);
  });

  testWidgets('graphics preset can be changed and diagnostics controls render',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AzerothApp());
    await tester.pump(const Duration(milliseconds: 100));

    final preset = find.byType(DropdownButtonFormField<String>);
    await tester.scrollUntilVisible(
      preset,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(preset);
    await tester.pump(const Duration(milliseconds: 100));
    expect(preset, findsOneWidget);

    await tester.tap(preset);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Medium').last, findsOneWidget);
    await tester.tap(find.text('Medium').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Graphics preset'), findsOneWidget);
  });


}
