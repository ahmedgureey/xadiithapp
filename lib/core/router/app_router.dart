import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../features/auth/auth_screens.dart';
import '../../features/collections/collections_screens.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/hadith/hadith_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/memorization/memorization_screens.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/profile/profile_screens.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),

      // Five bottom-navigation tabs; each keeps its own navigation stack.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/collections',
              builder: (_, _) => const CollectionsScreen(),
              routes: [
                GoRoute(
                  path: ':bookId',
                  builder: (_, s) => BookScreen(bookId: s.pathParameters['bookId']!, initial: s.extra as BookSummary?),
                  routes: [
                    GoRoute(
                      path: 'chapters/:chapterId',
                      builder: (_, s) => ChapterHadithsScreen(
                        bookId: s.pathParameters['bookId']!,
                        chapterId: s.pathParameters['chapterId']!,
                        chapter: s.extra as Chapter?,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (_, s) => SearchScreen(initialQuery: s.uri.queryParameters['q'])),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/memorization', builder: (_, _) => const MemorizationScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),

      // Full-screen routes shown above the bottom navigation.
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/hadith/:id',
        builder: (_, s) => HadithDetailScreen(hadithId: s.pathParameters['id']!, initial: s.extra as Hadith?),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/topics/:categoryId',
        builder: (_, s) => TopicHadithsScreen(categoryId: s.pathParameters['categoryId']!, category: s.extra as Category?),
      ),
      GoRoute(parentNavigatorKey: _rootKey, path: '/favorites', builder: (_, _) => const FavoritesScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/history', builder: (_, _) => const ReadingHistoryScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(parentNavigatorKey: _rootKey, path: '/review', builder: (_, _) => const ReviewSessionScreen()),
    ],
  );
});
