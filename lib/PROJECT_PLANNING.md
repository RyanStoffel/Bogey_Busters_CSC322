# Golf Shot Tracker App - Development TODO List

## CURRENT STATUS SUMMARY

**Last Updated:** November 2024

### Completed Phases
- **Phase 1: Project Setup & Foundation** - ~80% Complete
- **Phase 2: Data Models** - 100% Complete
- **Phase 3: Services & API Integration** - ~60% Complete (Auth & Firestore done)
- **Phase 4: Authentication Screens** - 100% Complete
- **Phase 5: Main Navigation Screens** - ~70% Complete (Home, Onboarding, Splash done)
- **Phase 6: Courses Screen** - ~40% Complete (Basic UI and CourseCard widget done)
- **Phase 15: Cloud Sync (Firestore)** - ~80% Complete (Basic CRUD and streams done)
- **Phase 16: Polish & UX Improvements** - ~40% Complete (Basic error handling and loading states)

### In Progress
- Home Screen enhancements (needs real data integration)
- Course search and filtering functionality

### Next Steps
1. Add Google Maps integration and location services
2. Implement Play Screen and round tracking flow
3. Add Golf API service for course data
4. Implement local database (Hive) for offline support
5. Build statistics calculation service
6. Create round tracking screens (Hole Screen, Scorecard, etc.)

### Key Achievements
- Complete authentication system with email/password and Google Sign-In
- Full user onboarding flow with profile creation
- All data models implemented with JSON serialization
- Firestore integration for cloud data storage
- Basic home screen with navigation structure
- Course card widget for displaying course information

---

## PHASE 1: PROJECT SETUP & FOUNDATION

- [x] Initialize Flutter project with proper structure
- [x] Set up folder structure ****(lib/screens, lib/models, lib/services, lib/widgets, lib/utils)
- [x] Add dependencies to pubspec.yaml (firebase, google_maps_flutter, geolocator, hive, http, provider/riverpod)
  - [x] Firebase dependencies (firebase_core, firebase_auth, cloud_firestore, firebase_storage)
  - [x] Google Sign-In (google_sign_in)
  - [x] Firebase UI (firebase_ui_auth, firebase_ui_oauth_google)
  - [x] Environment variables (flutter_dotenv)
  - [x] Image picker (image_picker)
  - [x] SVG support (flutter_svg)
  - [x] Google Maps (google_maps_flutter)
  - [x] Geolocator 
  - [x] HTTP - Not yet added
- [x] Configure Firebase project (iOS & Android)
- [x] Set up Firebase Authentication
- [x] Set up Firestore database structure
- [x] Configure Google Maps API keys (iOS & Android)
- [x] Set up location permissions (iOS Info.plist & Android Manifest)
- [x] Create app theme and color scheme (Green theme with Material 3)

## PHASE 2: DATA MODELS

- [x] Create User model (with JSON serialization)
- [x] Create Course model (with JSON serialization)
- [x] Create Hole model (with JSON serialization)
- [x] Create Round model (with JSON serialization)
- [x] Create Shot model (with JSON serialization)
- [x] Create ClubType enum (with display names and JSON conversion)
- [x] Create CoordinatePoint model (with JSON serialization)
- [x] Create Statistics model (with JSON serialization)
- [x] Create Club model (referenced in Shot model)
- [x] Create models.dart barrel file for exports

## PHASE 3: SERVICES & API INTEGRATION

- [x] Create AuthService for Firebase Authentication
  - [x] Email/password authentication (sign up, sign in, sign out)
  - [x] Google Sign-In integration
  - [x] Password reset functionality
  - [x] Email verification
  - [x] User document creation in Firestore
  - [x] Profile picture upload to Firebase Storage
  - [x] Onboarding completion tracking
  - [x] Account linking (Google account)
  - [x] Account deletion
- [x] Create GolfAPIService for fetching course data
- [x] Create LocationService for GPS tracking
- [x] Create FirestoreService for cloud data sync
  - [x] User profile operations (CRUD)
  - [x] Round operations (save, get, update, delete, stream)
  - [x] Statistics operations (save, get, stream)
  - [x] Favorite courses operations (save, get, remove)
- [ ] Create StatisticsService for calculating golf stats
- [x] Create services.dart barrel file for exports

## PHASE 4: AUTHENTICATION SCREENS

- [x] Design Login Screen UI in Figma
- [x] Build Login Screen with email/password fields
- [x] Implement login functionality with Firebase Auth
- [x] Add loading states and error handling to Login Screen
- [x] Design Signup Screen UI in Figma
- [x] Build Signup Screen with form validation
- [x] Implement signup functionality with Firebase Auth
- [x] Add password validation (minimum 6 characters)
- [x] Add password visibility toggle
- [x] Design Verify Email Screen UI in Figma
- [x] Build Verify Email Screen
- [x] Implement email verification flow (auto-check with timer)
- [x] Add resend verification email button (with 30-second cooldown)
- [x] Design Forgot Password Screen UI in Figma
- [x] Build Forgot Password Screen (as dialog in AuthScreen)
- [x] Implement password reset functionality
- [x] Add success/error feedback (SnackBar messages)
- [x] Google Sign-In button integration
- [x] Toggle between Login/Signup modes
- [x] Form validation for all fields

## PHASE 5: MAIN NAVIGATION SCREENS

- [x] Design Home Screen UI in Figma
- [x] Build Home Screen with bottom navigation
  - [x] Home tab
  - [x] Courses tab
  - [x] Play tab (placeholder)
  - [x] Rounds tab (placeholder)
  - [x] Friends tab (placeholder)
- [x] Add quick stats dashboard to Home Screen (nearest course card)
- [x] Add quick action cards (Start Round, View Rounds, Find Courses, Friends)
- [x] Add drawer navigation with user profile
- [x] Add logout functionality
- [x] Add course list display (with dummy data)
- [x] Build Splash Screen with auth state checking
- [x] Build Onboarding Screen
  - [x] Profile picture upload (camera/gallery)
  - [x] First name, last name, username fields
  - [x] Gender selection
  - [x] Age input with validation
  - [x] Form validation
  - [x] Save to Firestore
- [x] Add account settings section
- [ ] Add app preferences (units, notifications)
- [ ] Add delete account option
- [x] Design Profile Screen UI in Figma
- [x] Build Profile Screen with user info
- [x] Add past rounds list view
- [ ] Add statistics overview cards
- [x] Add profile picture upload (in Onboarding Screen)
- [x] Add edit profile functionality

## PHASE 6: COURSES SCREEN

- [x] Design Courses Screen UI in Figma
- [x] Build Courses Screen with basic layout (integrated in Home Screen)
- [x] Add course list view (currently with dummy data)
- [x] Create CourseCard widget component
  - [x] Course card type (courseCard, courseScoreCard, friendCourseScoreCard)
  - [x] Course image display
  - [x] Course name, par, holes, distance
  - [x] Preview and Play buttons
- [x] Build Courses Screen with search bar
- [x] Implement course search by name
- [x] Add course list view with distance from user (currently placeholder distance)
- [ ] Add course favorites functionality
- [x] Create Course Detail view
- [x] Display course info (holes, par, rating, slope)
- [x] Show course location on map

## PHASE 7: PLAY SCREEN & COURSE SELECTION

- [x] Design Play Screen UI in Figma
- [x] Build Play Screen layout
- [x] Implement "Find Nearest Course" functionality using GPS
- [x] Display nearest course card with details
- [x] Add "Start Round" button
- [x] Add loading states while fetching course data from API

## PHASE 8: ROUND DETAILS SCREEN

- [x] Design Round Details Screen UI in Figma
- [x] Build Round Details Screen
- [x] Display course name and date
- [x] Add tee selection (Blue, White, Red, Gold)
- [ ] Add playing partners input (optional)
- [x] Add "Start Round" confirmation button
- [x] Create new round in database when started

## PHASE 9: HOLE SCREEN (CORE FEATURE)

- [x] Design Hole Screen UI in Figma
- [x] Build Hole Screen layout with map integration
- [x] Integrate Google Maps with course overlay
- [x] Display tee boxes on map from API coordinates
- [x] Display green on map from API coordinates
- [x] Implement real-time GPS tracking
- [x] Display current position on map with blue dot
- [x] Show distance to green dynamically
- [ ] Build club selector horizontal scroll view
- [ ] Add all club types to selector (Driver, Woods, Irons, Wedges, Putter)
- [ ] Implement club selection highlighting
- [ ] Build "Mark Shot" floating action button
- [ ] Implement shot marking functionality
- [ ] Calculate distance from previous shot/tee
- [ ] Save shot to local database
- [ ] Display shot markers on map
- [ ] Draw polylines connecting shots
- [ ] Show shot info in InfoWindow (club, distance)
- [ ] Add shot counter display
- [ ] Add current score input for hole
- [ ] Build "Next Hole" button
- [ ] Implement hole progression (1-18)
- [ ] Add "View Scorecard" button in app bar
- [ ] Handle round completion after hole 18

## PHASE 10: SCORECARD SCREEN

- [ ] Design Scorecard Screen UI in Figma
- [ ] Build Scorecard Screen with hole-by-hole view
- [ ] Display par for each hole
- [ ] Display strokes for each hole
- [ ] Calculate score relative to par (+/- display)
- [ ] Show front 9, back 9, and total scores
- [ ] Add ability to edit scores
- [ ] Add "Return to Round" button

## PHASE 11: END OF ROUND SCREEN

- [ ] Design End of Round Screen UI in Figma
- [ ] Build End of Round Screen
- [ ] Display final score summary
- [ ] Show total strokes and score relative to par
- [ ] Display round statistics (fairways hit, GIR, putts)
- [ ] Add "Save Round" button
- [ ] Add "Discard Round" option
- [ ] Sync round data to Firestore
- [ ] Navigate to Past Round Details after save

## PHASE 12: PAST ROUND DETAILS SCREEN

- [ ] Design Past Round Details Screen UI in Figma
- [ ] Build Past Round Details Screen
- [ ] Display course name, date, and final score
- [ ] Show hole-by-hole scorecard
- [ ] Display shot map for each hole
- [ ] Show club usage statistics for the round
- [ ] Display distance statistics
- [ ] Add "Share Round" functionality
- [ ] Add "Delete Round" option

## PHASE 13: STATISTICS & ANALYTICS

- [ ] Design statistics cards for Profile Screen
- [ ] Calculate average score
- [ ] Calculate best score
- [ ] Calculate rounds played
- [ ] Calculate average putts per round
- [ ] Calculate fairways hit percentage
- [ ] Calculate greens in regulation percentage
- [ ] Calculate average driver distance
- [ ] Create statistics visualization charts
- [ ] Add date range filters for stats
- [ ] Implement club performance analytics

## PHASE 14: LOCAL DATABASE (hive)

- [ ] Create database schema for rounds
- [ ] Create database schema for shots
- [ ] Create database schema for courses (cached)
- [ ] Implement CRUD operations for rounds
- [ ] Implement CRUD operations for shots
- [ ] Add database migration support

## PHASE 15: CLOUD SYNC (Firestore)

- [x] Set up Firestore collections structure
  - [x] users collection (user profiles)
  - [x] users/{userId}/rounds subcollection
  - [x] users/{userId}/statistics subcollection
  - [x] users/{userId}/favoriteCourses subcollection
- [x] Implement round sync to Firestore (CRUD operations in FirestoreService)
- [x] Implement shot sync to Firestore (via Round model)
- [x] Stream support for rounds and statistics
- [ ] Add offline support with sync queue
- [ ] Handle sync conflicts
- [ ] Add background sync service

## PHASE 16: POLISH & UX IMPROVEMENTS

- [x] Add loading indicators throughout app (CircularProgressIndicator in auth screens, onboarding)
- [x] Implement error handling and user feedback (SnackBar messages with error/success states)
- [x] Add empty states for screens with no data (placeholder screens for Play, Rounds, Friends tabs)
- [x] Add onboarding flow for first-time users (OnboardingScreen with profile setup)
- [ ] Add confirmation dialogs for destructive actions
- [ ] Implement pull-to-refresh on list screens
- [ ] Implement app tutorial for shot tracking
- [ ] Add haptic feedback for button presses
- [ ] Optimize map performance
- [ ] Add dark mode support
- [ ] Implement accessibility features

## PHASE 17: TESTING

- [ ] Write unit tests for models
- [ ] Write unit tests for services
- [ ] Write widget tests for key screens
- [ ] Write integration tests for authentication flow
- [ ] Write integration tests for round tracking flow
- [ ] Test GPS accuracy in different conditions
- [ ] Test offline functionality
- [ ] Perform user acceptance testing

## PHASE 18: DEPLOYMENT

- [ ] Set up app icons for iOS and Android
- [ ] Set up splash screen
- [ ] Configure iOS build settings
- [ ] Configure Android build settings
- [ ] Set up code signing for iOS
- [ ] Set up signing keys for Android
- [ ] Create app store screenshots
- [ ] Write app store description
- [ ] Submit to Apple App Store
- [ ] Submit to Google Play Store