import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('WOW LK launcher renders its main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AzerothApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('WOW LK'), findsOneWidget);
    expect(find.text('Automatic hardware scan'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SELECT WOW GAME FOLDER'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SELECT WOW GAME FOLDER'), findsOneWidget);
    expect(find.text('GAME'), findsOneWidget);
    expect(find.text('REALMS'), findsOneWidget);
    expect(find.text('OPTIONS'), findsOneWidget);
  });
}
