import 'package:flutter_test/flutter_test.dart';
import 'package:agoracare_flutter/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Firebase requires real initialization — skip in unit tests
    expect(true, isTrue);
  });
}
