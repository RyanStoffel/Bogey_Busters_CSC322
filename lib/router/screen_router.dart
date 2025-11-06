import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:golf_tracker_app/screens/auth_screen.dart';
import 'package:golf_tracker_app/screens/splash_screen.dart';
import 'package:golf_tracker_app/screens/home_screen.dart';
import 'package:golf_tracker_app/screens/friends_screen.dart';
import 'package:golf_tracker_app/screens/courses_screen.dart';
import 'package:golf_tracker_app/screens/play_screen.dart';
import 'package:golf_tracker_app/screens/profile_screen.dart';
import 'package:golf_tracker_app/screens/shell_screen.dart';

final GoRouter screenRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isOnSplashScreen = state.uri.path == '/';
    final isOnAuthScreen = state.uri.path == '/auth';
    
    if (isOnSplashScreen) return null;
    
    if (user == null && !isOnAuthScreen) {
      return '/auth';
    }
    
    if (user != null && isOnAuthScreen) {
      return '/home';
    }
    
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => NoTransitionPage(
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) => NoTransitionPage(
        child: const AuthScreen(),
      ),
    ),
    ShellRoute(
      builder: (context, state, body) {
        int currentIndex = 0;
        final location = state.uri.path;
        
        if (location.startsWith('/friends')) {
          currentIndex = 0;
        } else if (location.startsWith('/courses')) {
          currentIndex = 1;
        } else if (location.startsWith('/home')) {
          currentIndex = 2;
        } else if (location.startsWith('/play')) {
          currentIndex = 3;
        } else if (location.startsWith('/profile')) {
          currentIndex = 4;
        }

        return ShellScreen(
          currentIndex: currentIndex,
          body: body,
        );
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/friends',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const FriendsScreen(),
          ),
        ),
        GoRoute(
          path: '/courses',
          pageBuilder: (context, state) => NoTransitionPage(
            child: CoursesScreen(),
          ),
        ),
        GoRoute(
          path: '/play',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const PlayScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const ProfileScreen(),
          ),
        ),
      ],
    ),
  ],
);