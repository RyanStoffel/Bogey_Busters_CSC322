import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:golf_tracker_app/models/course.dart';
import 'package:golf_tracker_app/screens/auth_screen.dart';
import 'package:golf_tracker_app/screens/course_details_selection_screen.dart';
import 'package:golf_tracker_app/screens/course_preview_screen.dart';
import 'package:golf_tracker_app/screens/courses_screen.dart';
import 'package:golf_tracker_app/screens/edit_profile_screen.dart';
import 'package:golf_tracker_app/screens/friends_screen.dart';
import 'package:golf_tracker_app/screens/onboarding_screen.dart';
import 'package:golf_tracker_app/screens/profile_screen.dart';
import 'package:golf_tracker_app/screens/shell_screen.dart';
import 'package:golf_tracker_app/screens/splash_screen.dart';
import 'package:golf_tracker_app/screens/verify_email_screen.dart';
import 'package:golf_tracker_app/screens/in_round_screen.dart';
import 'package:golf_tracker_app/screens/end_of_round_screen.dart';
import 'package:golf_tracker_app/models/models.dart';
import 'package:golf_tracker_app/services/round_persistence_service.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    firebase_auth.FirebaseAuth.instance
        .authStateChanges()
        .listen((firebase_auth.User? user) {
      notifyListeners();
    });
  }
}

final _authNotifier = AuthNotifier();

final GoRouter screenRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    final isOnSplashScreen = state.uri.path == '/';
    final isOnAuthScreen = state.uri.path == '/auth';
    final isOnVerifyEmail = state.uri.path == '/verify-email';
    final isOnOnboarding = state.uri.path == '/onboarding';
    final isOnInRound = state.uri.path == '/in-round';

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
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

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
        
        // Check for active round before going to courses
        final persistenceService = RoundPersistenceService();
        final hasActiveRound = await persistenceService.hasActiveRound();
        
        if (hasActiveRound) {
          return '/in-round';
        }
        
        return '/courses';
      }

      // If not verified and not on verify-email page
      if (!user.emailVerified && !isOnVerifyEmail) {
        return '/verify-email';
      }

      // If verified but not on onboarding page, check if onboarding is needed
      if (user.emailVerified && !isOnOnboarding && !isOnInRound) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (doc.exists) {
            final data = doc.data();
            final onboardingCompleted = data?['onboardingCompleted'] ?? false;

            if (!onboardingCompleted) {
              return '/onboarding';
            }
            
            // After onboarding check, also check for active round
            final persistenceService = RoundPersistenceService();
            final hasActiveRound = await persistenceService.hasActiveRound();
            
            if (hasActiveRound) {
              return '/in-round';
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
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
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
      path: '/course-details',
      builder: (context, state) {
        final course = state.extra as Course;
        return CourseDetailsSelectionScreen(course: course);
      },
    ),
    GoRoute(
      path: '/in-round',
      builder: (context, state) {
        // The screen will handle loading saved state in initState
        // Just pass through the extra data if it exists
        final data = state.extra as Map<String, dynamic>?;
        
        if (data != null) {
          // Starting/resuming from course selection screen
          final course = data['course'] as Course;
          final teeColor = data['teeColor'] as String;
          final isResuming = data['isResumingRound'] as bool? ?? false;
          
          return InRoundScreen(
            course: course,
            teeColor: teeColor,
            isResumingRound: isResuming,
          );
        } else {
          // Coming from automatic redirect - screen will load state
          return const InRoundScreen(
            course: null,
            teeColor: null,
            isResumingRound: true,
          );
        }
      },
    ),
    GoRoute(
      path: '/end-of-round',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        final course = data['course'] as Course;
        final teeColor = data['teeColor'] as String;
        final holes = data['holes'] as List<Hole>;
        final holeScores = Map<int, int>.from(data['holeScores'] as Map);
        return EndOfRoundScreen(
          course: course,
          teeColor: teeColor,
          holes: holes,
          holeScores: holeScores,
        );
      },
    ),
    ShellRoute(
      builder: (context, state, body) {
        int currentIndex = 0;
        final location = state.uri.path;
        
        // Check for 'from' query parameter to track navigation source
        final fromParam = state.uri.queryParameters['from'];

        // Determine which tab should be highlighted
        if (fromParam == 'play' || location.startsWith('/friends')) {
          // If navigated from play button OR on friends screen
          currentIndex = 0;
        } else if (location.startsWith('/courses')) {
          // Only highlight courses if actually on courses, not from play button
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
              path: 'preview',
              pageBuilder: (context, state) {
                final course = state.extra as Course;
                return NoTransitionPage(
                  child: CoursePreviewScreen(course: course),
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