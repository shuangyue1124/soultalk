import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soultalk/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: SoulTalkApp(container: container),
      ),
    );

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify the app renders without crashing
    expect(find.byType(SoulTalkApp), findsOneWidget);
  });
}
