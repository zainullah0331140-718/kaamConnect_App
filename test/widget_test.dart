import 'package:flutter_test/flutter_test.dart';
import 'package:kaamconnect_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('KaamConnect app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KaamConnectApp());
    expect(find.text('KaamConnect'), findsWidgets);
  });
}
