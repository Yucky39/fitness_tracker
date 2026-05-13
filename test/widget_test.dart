import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_tracker/main.dart';
import 'package:fitness_tracker/providers/auth_provider.dart';

void main() {
  testWidgets('shows auth screen when signed out', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: const FitnessTrackerApp(),
      ),
    );

    await tester.pump();

    expect(find.text('BeWell'), findsOneWidget);
    expect(find.text('ログイン'), findsWidgets);
    expect(find.text('新規登録'), findsOneWidget);
  });
}
