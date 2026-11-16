import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('Azeroth Mobile launcher renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AzerothApp());
    expect(find.text('AZEROTH MOBILE'), findsOneWidget);
    expect(find.text('IMPORT GAME FOLDER'), findsOneWidget);
    expect(find.text('SERVER MANAGER'), findsOneWidget);
  });
}
