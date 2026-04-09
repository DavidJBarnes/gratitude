import 'package:flutter_test/flutter_test.dart';
import 'package:gratitude_app/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const GratitudeApp(isLoggedIn: false));
    expect(find.text('Gratitude'), findsOneWidget);
  });
}
