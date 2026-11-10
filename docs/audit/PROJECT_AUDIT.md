# LearnSign PH Project Audit

Audit date: 2026-11-10. Scope: read-only source, configuration, asset, test, and build audit. No product features were implemented and no database schema was changed.

## Executive summary

LearnSign PH is a Flutter application with a working compile-time foundation and a partially implemented Firebase learning experience. The verified core is email/password authentication, Firestore-backed lessons and signs, lesson detail media presentation, a generated multiple-choice quiz, lesson progress writes, a profile/dashboard view, and a Firestore-backed sentence-order grammar exercise. The application currently has no verified production curriculum because the seed data uses public demonstration media and no local teaching assets are present.

The main completion blockers are:

- The Windows build fails during Firebase C++ SDK CMake configuration because the generated Firebase SDK requires a CMake policy update compatible with the installed CMake.
- The Live tab is explicitly a camera placeholder; there is no camera, MediaPipe, classifier, permission flow, or recognition implementation.
- Several gamification values are client-calculated and user-writable under the current Firestore rules. A learner may be able to alter points, level, streak, badges, and counters through direct Firestore writes.
- Seeded FSL media is demonstrably placeholder content: Cloudinary demo elephants.mp4 and a generic Giphy GIF. FSL correctness, consent, licensing, and Deaf-community review are unverified.
- The 12-entry Grammar Hub is a hardcoded catalog of exercise IDs; the screen does not prove that all corresponding Firestore exercises exist.
- A content manager exists behind an email check, but it edits signs and lessons only and does not provide complete quiz/exercise administration.

## Architecture audit

### Structure

- lib/main.dart: Firebase initialization, authentication gate, and app root.
- lib/screens/auth/: login and registration.
- lib/screens/main_navigation_screen.dart: bottom navigation, dashboard, grammar hub, and live-practice placeholder.
- lib/screens/lessons/: Firestore lesson list/detail and generated lesson quiz.
- lib/screens/grammar/: Firestore sentence-order exercise and drag/drop interaction.
- lib/screens/profile*.dart and lib/screens/profile/: profile, progress, history, streak, badges, account settings, and content manager.
- lib/models/: lesson, sign, lesson progress, grammar exercise/tile/progress models.
- lib/services/: Firestore access, seed data, grammar access, Firebase Storage helpers, and Cloudinary profile uploads.
- lib/widgets/: video player and GIF tile.
- test/: four focused unit/widget test files.

The code is feature-foldered but not a strict layered architecture. Screens call service classes directly; there is no repository/use-case layer, dependency injection, route table, or centralized state-management package. State is primarily local StatefulWidget state plus Firestore streams and one-time reads.

### State and navigation

Navigation is a MaterialApp with an auth gate and a NavigationBar/IndexedStack. Detail screens use direct MaterialPageRoute pushes. This is adequate for the current slice but does not provide named/deep-link routes, URL navigation, route guards beyond the auth gate, or an explicit desktop navigation strategy.

### Persistence and backend

Firebase is initialized with generated platform options. Firestore stores users, lessons, signs, grammarExercises, and per-user lessonProgress/grammarProgress. Firebase Storage rules define media paths for signs and lessons. Cloudinary is used for user profile images through an unsigned upload preset. Timestamps are stored as ISO strings rather than Firestore server timestamps.

### Platform support

Flutter doctor confirms Android, Chrome/web, and Windows toolchains are available. Web builds successfully. Windows source and Firebase plugin registration exist, but the Windows build is currently blocked by CMake/Firebase SDK configuration. Android configuration and google-services.json exist, but no Android runtime or device flow was executed in this audit. iOS, macOS, and Linux scaffolding also exists but is outside the requested immediate priority.

### Assets and content

assets/images/ and assets/ml_models/ contain only .gitkeep files. There are no checked-in lesson images, GIFs, videos, or ML models. Content is expected to be remote Firestore URLs. The seed class contains 31 sign records and 14 lesson records, with several placeholder media URLs and empty lesson video URLs.

### Technical debt and risks

- Hardcoded content-admin email appears in client code and security rules.
- Firestore rules allow an authenticated user to update their own entire users/{userId} document, including fields that represent rewards and achievements.
- XP is awarded by a client-callable method and is not transactionally protected against duplicate completion submissions.
- markLessonCompleted can increment lesson counters repeatedly if called again for the same lesson.
- Lesson quiz correctness is based on English word labels, not a verified FSL assessment.
- getSignsByIds uses one whereIn query; the code comments only support up to 30 IDs and does not chunk larger lessons.
- Hardcoded UI catalogs and seed data can drift from Firestore.
- No live Firebase data, Storage upload, media reachability, or accessibility behavior was verified.

## Audit conclusion

The project is suitable for a controlled MVP after the Windows build issue, content replacement, security hardening, and end-to-end verification are addressed. It is not yet ready to present as a complete FSL learning product. Preserve the current Firebase lesson/quiz/grammar slice while adding tests and authoritative content; do not expand gamification or camera recognition until the data and authorization model are secured.
