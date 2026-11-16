import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('WOW LK launcher renders its main screen', (WidgetTester tester) async {
    await tester.view.setPhysicalSize(const Size(900, 1800));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const AzerothApp());
    await tester.pumpAndSettle();
    expect(find.text('WOW LK'), findsOneWidget);
    expect(find.text('SELECT WOW GAME FOLDER'), findsOneWidget);
    expect(find.text('GAME'), findsOneWidget);
    expect(find.text('REALMS'), findsOneWidget);
    expect(find.text('OPTIONS'), findsOneWidget);
  });
}
