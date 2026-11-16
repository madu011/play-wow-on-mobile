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

    await tester.scrollUntilVisible(
      find.text('Graphics preset'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Medium').last);
    await tester.pumpAndSettle();

    expect(find.text('Graphics preset'), findsOneWidget);
    expect(find.text('RESCAN DEVICE'), findsOneWidget);
    expect(find.text('COPY REPORT'), findsOneWidget);
  });
}
