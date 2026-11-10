# LearnSign PH Bug and Risk Report

## Critical/high priority

### BUG-001 — Windows build fails in Firebase C++ SDK configuration

- Severity: High; blocks the immediate Windows target.
- Reproduction: run flutter build windows.
- Actual result: CMake reports Compatibility with CMake < 3.5 has been removed from build/windows/x64/extracted/firebase_cpp_sdk_windows/CMakeLists.txt, then fails to generate build files.
- Fix direction: inspect installed CMake/Firebase plugin versions and apply a supported configuration change; do not patch generated SDK blindly.

### BUG-002 — Seeded demonstrations are not valid FSL curriculum

- Severity: Critical content/release risk.
- Evidence: firestore_seed.dart uses Cloudinary demo elephants.mp4 and a generic Giphy URL for many signs.
- Impact: users can be shown unrelated media while labels claim FSL meanings.
- Fix direction: replace with licensed, reviewed FSL demonstrations and record source, signer consent, review status, and version.

### BUG-003 — Learner-controlled reward fields

- Severity: Critical security/integrity risk.
- Evidence: firestore.rules allows an authenticated user to update their own users/{userId} document; firestore_service.dart writes points, level, streak, badges, and lesson counters from the client.
- Impact: direct Firestore clients may forge progress and rewards.
- Fix direction: restrict mutable profile fields, move authoritative reward calculations to trusted backend logic/transactions, and add emulator/rules tests.

### BUG-004 — Duplicate completion can award duplicate XP and counts

- Severity: High.
- Evidence: markLessonCompleted always adds points and the streak/lesson updater always increments lessonsCompleted; no prior completed-state guard or transaction is visible.
- Reproduction: submit the same perfect lesson more than once or call the method repeatedly.
- Fix direction: make completion idempotent and transactionally award only once.

### BUG-005 — Live tab advertises a feature that is not implemented

- Severity: High product completeness.
- Evidence: LivePracticeScreen displays “Camera UI is still in progress”; no camera/MediaPipe dependency or implementation exists.
- Fix direction: hide/gate the tab for MVP or implement camera permission, lifecycle, and recognition flow.

## Medium priority

### BUG-006 — Grammar Hub IDs are hardcoded and may not exist

- Severity: Medium.
- Evidence: 12 IDs are declared in GrammarHubScreen, while seed content is the source of exercise creation; the hub does not filter to existing exercises.
- Impact: tapping an unseeded ID leads to a not-found/error state.
- Fix direction: stream available exercises or show an unavailable state.

### BUG-007 — Admin authorization is duplicated as a hardcoded email

- Severity: Medium security/operations.
- Evidence: the same email is embedded in client code and Firestore/Storage rules.
- Fix direction: use Firebase custom claims or an admin-role document; keep server rules authoritative.

### BUG-008 — Lesson quiz uses word labels as assessment truth

- Severity: Medium content/learning validity.
- Evidence: lesson questions compare selected strings to sign.word; no verified sign assessment metadata exists.
- Fix direction: add reviewed assessment content and explicit answer metadata.

### BUG-009 — Media controls are incomplete

- Severity: Medium UX.
- Evidence: video_player is used directly; chewie is declared but no ChewieController is present. Loading/error/retry exists, but normal playback controls are not exposed.
- Fix direction: add accessible play/pause, seek, volume, progress, and fullscreen controls or remove the unused dependency later.

### BUG-010 — Desktop layout is unverified and mobile-oriented

- Severity: Medium.
- Evidence: fixed bottom navigation, fixed 220px video, fixed two-column dashboard grid, and no responsive layout code or Windows UI test.
- Fix direction: exercise keyboard/focus/resize paths on Windows and add breakpoint-aware layouts.

## Low priority / technical debt

- assets/images/ and assets/ml_models/ contain only .gitkeep; declarations can imply content exists.
- getSignsByIds does not chunk more than 30 IDs despite its own comment identifying the Firestore limit.
- ISO string timestamps are used for activity/progress; server timestamps would reduce client-clock inconsistencies.
- No route table/deep links are defined, limiting web and desktop navigation.
- No emulator rules tests, integration tests, or platform tests were found.

## Unverified runtime checks

The audit did not claim Android runtime, live Firebase data, Storage uploads, Cloudinary uploads, video reachability, or accessibility behavior as verified. These require configured services, a device/emulator, and authoritative test content.
