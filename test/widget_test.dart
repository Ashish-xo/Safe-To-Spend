import 'package:flutter_test/flutter_test.dart';
import 'package:safe_to_spend/main.dart';

void main() {
  testWidgets('App boots to shell', (tester) async {
    await tester.pumpWidget(const SafeToSpendApp());
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Assistant'), findsOneWidget);
  });
}
