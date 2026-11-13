import 'package:flutter_test/flutter_test.dart';
import 'package:senior2/main.dart';

void main() {
  testWidgets('Kidsential app test', (WidgetTester tester) async {
    await tester.pumpWidget(const KidsentialApp());

    expect(find.byType(KidsentialApp), findsOneWidget);
  });
}