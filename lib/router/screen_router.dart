import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/course.dart';
import 'package:golf_tracker_app/screens/auth_screen.dart';
import 'package:golf_tracker_app/screens/course_preview_screen.dart';
import 'package:golf_tracker_app/screens/courses_screen.dart';
import 'package:golf_tracker_app/screens/edit_profile_screen.dart';
import 'package:golf_tracker_app/screens/friends_screen.dart';
import 'package:golf_tracker_app/screens/onboarding_screen.dart';
import 'package:golf_tracker_app/screens/play_screen.dart';
import 'package:golf_tracker_app/screens/profile_screen.dart';
import 'package:golf_tracker_app/screens/shell_screen.dart';
import 'package:golf_tracker_app/screens/splash_screen.dart';
import 'package:golf_tracker_app/screens/verify_email_screen.dart';
import 'package:golf_tracker_app/screens/in_round_screen.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

final GoRouter screenRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final isOnSplashScreen = state.uri.path == '/';
    final isOnAuthScreen = state.uri.path == '/auth';
    final isOnVerifyEmail = state.uri.path == '/verify-email';
    final isOnOnboarding = state.uri.path == '/onboarding';

    if (isOnSplashScreen) return null;

    // No user - redirect to auth
    if (user == null && !isOnAuthScreen) {
      return '/auth';
    }

    // User exists - check verification and onboarding status
    if (user != null) {
      // If on auth screen and logged in, need to check verification
      if (isOnAuthScreen) {
        if (!user.emailVerified) {
          return '/verify-email';
        }

        // Check onboarding status
        try {
          final doc =
              await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (doc.exists) {
            final data = doc.data();
            final onboardingCompleted = data?['onboardingCompleted'] ?? false;

            if (!onboardingCompleted) {
              return '/onboarding';
            }
          }
        } catch (e) {
          // If we can't check, assume they need onboarding
          return '/onboarding';
        }
        return '/play';
      }

      // If not verified and not on verify-email page
      if (!user.emailVerified && !isOnVerifyEmail) {
        return '/verify-email';
      }

      // If verified but not on onboarding page, check if onboarding is needed
      if (user.emailVerified && !isOnOnboarding) {
        try {
          final doc =
              await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

          if (doc.exists) {
            final data = doc.data();
            final onboardingCompleted = data?['onboardingCompleted'] ?? false;

            if (!onboardingCompleted) {
              return '/onboarding';
            }
          } else {
            return '/onboarding';
          }
        } catch (e) {
          return '/onboarding';
        }
      }
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
    GoRoute(
      path: '/verify-email',
      pageBuilder: (context, state) {
        final user = FirebaseAuth.instance.currentUser;
        return NoTransitionPage(
          child: VerifyEmailScreen(email: user?.email ?? ''),
        );
      },
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) => NoTransitionPage(
        child: const OnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/in-round',
      builder: (context, state) {
        final course = state.extra as Course;
        return InRoundScreen(course: course);
      },
    ),
    ShellRoute(
      builder: (context, state, body) {
        int currentIndex = 0;
        final location = state.uri.path;

        if (location.startsWith('/friends')) {
          currentIndex = 0;
        } else if (location.startsWith('/courses')) {
          currentIndex = 1;
        } else if (location.startsWith('/in-round-screen')) {
          currentIndex = 2;
        } else if (location.startsWith('/profile')) {
          currentIndex = 3;
        }

        return ShellScreen(
          currentIndex: currentIndex,
          body: body,
        );
      },
      routes: [
        GoRoute(
          path: '/friends',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const FriendsScreen(),
          ),
        ),
        GoRoute(
          path: '/courses',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const CoursesScreen(),
          ),
          routes: [
            GoRoute(
              path: 'preview/:courseId',
              pageBuilder: (context, state) {
                final courseId = Uri.decodeComponent(state.pathParameters['courseId']!);
                return NoTransitionPage(
                  child: CoursePreviewScreen(courseId: courseId),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/play',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const PlayScreen(),
          ),
          routes: [
            GoRoute(
              path: 'course/:courseId',
              pageBuilder: (context, state) {
                final courseId = Uri.decodeComponent(state.pathParameters['courseId']!);
                return NoTransitionPage(
                  child: CoursePreviewScreen(courseId: courseId),
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const ProfileScreen(),
          ),
        ),
        GoRoute(
          path: '/edit-profile',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const EditProfileScreen(),
          ),
        ),
      ],
    ),
  ],
);