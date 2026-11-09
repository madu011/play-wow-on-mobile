import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('Azeroth Mobile launcher renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AzerothApp());
    expect(find.text('Azeroth Mobile'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });
}
