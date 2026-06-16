// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';

void main() {
  testWidgets('QuickPOS Pro app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickPOSApp());
    expect(find.text('QuickPOS Pro'), findsOneWidget);
  });
}
