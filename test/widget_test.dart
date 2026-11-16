import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('WOW LK launcher renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AzerothApp());
    expect(find.text('WOW LK'), findsOneWidget);
    expect(find.text('IMPORT GAME FOLDER'), findsOneWidget);
    expect(find.text('SERVER MANAGER'), findsOneWidget);
  });
}
