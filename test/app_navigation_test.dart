import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xadiithapp/app.dart';
import 'package:xadiithapp/core/providers.dart';
import 'package:xadiithapp/core/storage/token_storage.dart';

import 'helpers/fake_api.dart';

Future<void> _pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}, FakeHandler handler = defaultRoutes}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final tokens = MemoryTokenStorage();
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      tokenStorageProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWithValue(fakeApiClient(handler: handler, tokens: tokens)),
    ],
    child: const XadiisApp(),
  ));
}

void main() {
  testWidgets('first launch: splash → onboarding → home', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Xadiis App'), findsOneWidget);
    expect(find.text('Akhri, Fahan, Baro, Xifdi.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Ku akhri Carabi iyo Soomaali'), findsOneWidget);

    await tester.tap(find.text('Ka bood'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Xadiiska Maanta'), findsOneWidget);
    // No published Hadith yet → honest empty state, never placeholder text.
    expect(find.textContaining('Weli lama daabicin'), findsOneWidget);
  });

  testWidgets('every bottom navigation tab opens its screen', (tester) async {
    await _pumpApp(tester, prefs: {'onboarding_done': true, 'language': 'en'});
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    final nav = find.byType(NavigationBar);
    Future<void> tapTab(String label) async {
      await tester.tap(find.descendant(of: nav, matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await tapTab('Collections');
    expect(find.text('Hadith Collections'), findsOneWidget);
    expect(find.text('Test Book'), findsOneWidget);

    await tapTab('Search');
    expect(find.text('Search by Arabic text, Somali translation, collection name or Hadith number.'), findsOneWidget);

    await tapTab('Memorize');
    expect(find.text('Memorization'), findsOneWidget);
    expect(find.textContaining('Sign in so your memorization'), findsOneWidget);

    await tapTab('Profile');
    expect(find.text('Guest'), findsOneWidget);

    await tapTab('Home');
    expect(find.text('Hadith of the Day'), findsOneWidget);
  });

  testWidgets('collections fall back to the six known books when offline', (tester) async {
    await _pumpApp(
      tester,
      prefs: {'onboarding_done': true, 'language': 'en'},
      handler: (o) => (503, {'statusCode': 503, 'message': 'down'}),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Collections')));
    await tester.pumpAndSettle();
    expect(find.text('Sahih al-Bukhari'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sunan Ibn Majah'), 200);
    expect(find.text('Sunan Ibn Majah'), findsOneWidget);
  });

  testWidgets('hadith details show Arabic, Somali, grading and toggle favorite', (tester) async {
    await _pumpApp(
      tester,
      prefs: {'onboarding_done': true, 'language': 'en'},
      handler: (o) => switch (o.path) {
        '/hadiths/h1' => (200, {'data': testHadithJson()}),
        '/hadith-of-the-day' => (200, {'data': testHadithJson()}),
        _ => defaultRoutes(o),
      },
    );
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TEST ARABIC TEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Somali translation'), findsOneWidget);
    expect(find.text('TEST SOMALI TEXT'), findsOneWidget);
    expect(find.text('TEST-GRADE'), findsWidgets);

    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
  });
}
