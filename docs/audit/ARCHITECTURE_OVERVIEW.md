# LearnSign PH Current Architecture

## Runtime flow

~~~text
main.dart
  └─ Firebase.initializeApp(DefaultFirebaseOptions.currentPlatform)
      └─ FirebaseAuth.authStateChanges()
          ├─ LoginScreen / RegisterScreen
          └─ MainNavigationScreen
              ├─ DashboardScreen ── FirestoreService user profile/progress
              ├─ LessonListScreen ── FirestoreService lessons + progress
              ├─ LivePracticeScreen ── placeholder only
              ├─ GrammarHubScreen ── hardcoded IDs
              └─ ProfileScreen ── profile/detail/account/content manager
~~~

## Layers actually present

### Presentation

Flutter screens contain most view state, validation, loading flags, error text, navigation, and action handlers. Reusable presentation is limited to SignVideoPlayer, SignGifTile, StatsCard, and theme constants.

### Domain/data models

Plain Dart models represent lessons, signs, lesson progress, and grammar exercise/tile/progress. They map Firestore maps directly and contain little validation or domain behavior.

### Services

- FirestoreService: users, lessons, signs, lesson progress, points, streaks, badges, and profile updates.
- GrammarFirestoreService: grammar exercise retrieval and per-user grammar progress.
- MediaStorageService: file extension, MIME type, safe name, and Firebase Storage path helpers.
- CloudinaryProfileService: multipart profile-image upload using a configured unsigned preset.
- FirestoreSeed: client-accessible seed routines for demo signs, lessons, and exercises.

There is no repository abstraction, service locator, dependency injection, BLoC/Provider/Riverpod layer, background sync, cache, or offline data layer.

## Firebase data model observed

~~~text
users/{userId}
  uid, email, displayName, age, bio, photoUrl,
  points, level, streak, lastActivityDate, badges,
  lessonsCompleted, timestamps

users/{userId}/lessonProgress/{lessonId}
  status, score, updatedAt

users/{userId}/grammarProgress/{exerciseId}
  attempts, score, status, updatedAt

lessons/{lessonId}
  title, category, description, signIds, imageUrl, videoUrl

signs/{signId}
  word, category, difficulty, imageUrl, gifUrl, videoUrl

grammarExercises/{exerciseId}
  lessonId/prompt/difficulty/tile data
~~~

## Dependencies

Direct dependencies are Flutter, Cupertino icons, Firebase Core/Auth/Firestore/Storage, image_picker, http, video_player, and chewie. Tests use flutter_test; linting uses flutter_lints. chewie is declared but the inspected player uses video_player directly.

## Authorization model

Firestore and Storage rules use a hardcoded content-admin email. Learners can read lessons/signs publicly, read grammar exercises only when signed in, and read/write their own progress. Users can read/create/update their own profile document. The broad profile update rule is insufficient to protect reward fields; custom claims or trusted backend enforcement is required before production.

## Content/media model

Content is remote-first. There are no real local teaching assets or ML model files. The content manager can edit URLs and upload images/GIFs/videos to Firebase Storage. Seed data is demo-oriented and must not be interpreted as verified FSL instruction.

## Testing and build posture

The repository contains four focused test files covering grammar ordering, GIF tile layout, media path helpers, and user-progress calculations. flutter analyze, flutter test, and flutter build web passed during this audit. flutter build windows failed in Firebase C++ SDK CMake configuration. No integration, Firebase emulator rules, Android device, live media, or accessibility test suite was found.

## Architectural recommendations

Preserve the current feature boundaries for the MVP, then introduce a small repository/use-case boundary around progress and rewards, a typed authorization model, server timestamps, idempotent transactions, data-driven exercise catalogs, and a route abstraction. Keep content and review metadata outside UI code so reviewed FSL materials can be updated without shipping a new client.
