import 'package:flutter_test/flutter_test.dart';
import 'package:play_wow_on_mobile/main.dart';

void main() {
  testWidgets('WOW LK launcher renders its main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AzerothApp());
    await tester.pumpAndSettle();
    expect(find.text('WOW LK'), findsOneWidget);
    expect(find.text('SELECT WOW GAME FOLDER'), findsOneWidget);
    expect(find.text('GAME'), findsOneWidget);
    expect(find.text('REALMS'), findsOneWidget);
    expect(find.text('OPTIONS'), findsOneWidget);
  });
}
