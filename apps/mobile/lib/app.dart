import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/auth/verify_email_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/decks/deck_detail_screen.dart';
import 'features/decks/decks_screen.dart';
import 'features/main/main_screen.dart';
import 'features/review/review_screen.dart';
import 'features/study/study_screen.dart';

class FlashMindApp extends ConsumerWidget {
  const FlashMindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'FlashMind',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B12),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xFF0F0F1A),
          indicatorColor: Color(0xFF6366F1),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      routerConfig: router,
    );
  }
}

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      if (auth.bootstrapping) {
        return loc == '/' ? null : '/';
      }

      final loggedIn = auth.isAuthenticated;
      final needsVerification = auth.needsEmailVerification;
      final isPublic = loc == '/login' || loc == '/register';
      final isVerify = loc == '/verify-email';

      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn && needsVerification && !isVerify) return '/verify-email';
      if (loggedIn &&
          !needsVerification &&
          (isPublic || isVerify || loc == '/')) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(
        path: '/decks/:deckId',
        builder: (_, state) => DeckDetailScreen(
          deckId: state.pathParameters['deckId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, __) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/decks',
                builder: (_, __) => const DecksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/review',
                builder: (_, __) => const ReviewScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/study/:deckId',
        builder: (_, state) =>
            StudyScreen(deckId: state.pathParameters['deckId']!),
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
