import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_viz_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CryptoVizApp());
    expect(find.text('Crypto VIZ'), findsOneWidget);
  });
}
