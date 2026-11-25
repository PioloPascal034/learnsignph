# LearnSignPH — Grammar Drag-and-Drop Feature

Adds the in-lesson grammar drag-and-drop exercise (per your Firestore_Schema.docx
GrammarExercises/GrammarTiles design), using lightweight looping GIFs per sign
instead of full videos — since several tiles are visible on screen at once,
GIFs keep the screen fast and the data usage low compared to running multiple
video players simultaneously.

## What's new / changed

**New files:**
- `lib/models/grammar_exercise_model.dart`
- `lib/models/grammar_tile_model.dart`
- `lib/models/grammar_progress_model.dart`
- `lib/services/grammar_firestore_service.dart`
- `lib/screens/grammar/grammar_practice_screen.dart` — the actual drag-and-drop UI
- `lib/widgets/sign_gif_tile.dart` — reusable GIF+label tile (draggable tile and drop-slot both use this)

**Changed file:**
- `lib/models/sign_model.dart` — added a `gifUrl` field. Falls back to `videoUrl`
  automatically if a sign doc doesn't have a gif yet, so nothing breaks while
  you backfill real GIFs.

**Schema change:** `signs/{signId}` documents now also have a `gifUrl` field,
and there's a new `grammarExercises` collection (already in your original
schema doc — this just actually seeds and uses it now).

## How the drag-and-drop works

- Each exercise shows a prompt sentence (e.g. "I need help from the doctor.")
- Below it: empty ordered slots (one per tile) and a shuffled pool of draggable
  sign tiles, each showing its looping GIF + word
- Drag a tile into a slot; tap a filled slot to send that tile back to the pool
- "Check Answer" compares the slot order against each tile's `correctPosition`
  and shows a green/red result banner
- Every check (right or wrong) is recorded to
  `users/{userId}/grammarProgress/{exerciseId}` via `recordAttempt()` —
  `attempts` always increments, `status`/`score` only improve on a correct answer
- "Reset" reshuffles the pool and clears all slots for another try

## Integration steps

1. **Copy the new/changed files** into your project's `lib/` folder, matching
   the same folder structure shown above (overwrite `sign_model.dart`).

2. **Re-run the seed script** — use `seed_updated.js` instead of your old
   `seed.js` (rename it to `seed.js` or just run it directly). It adds
   `gifUrl` to every sign and creates one sample grammar exercise
   (`grammar_hospital_help`) tied to your existing "At the Hospital" lesson.
   Safe to re-run — same fixed document IDs as before, so it just updates
   existing docs rather than duplicating them.

3. **Update your Firestore Security Rules** to allow reading grammar content
   and writing grammar progress:
   ```
   match /grammarExercises/{exerciseId} {
     allow read: if request.auth != null;
     allow write: if false;
   }
   match /users/{userId}/grammarProgress/{exerciseId} {
     allow read, write: if request.auth != null && request.auth.uid == userId;
   }
   ```
   (Add these inside your existing `match /databases/{database}/documents { ... }`
   block, alongside the `lessons`/`signs`/`lessonProgress` rules you already have.)

4. **Add a way to reach the screen for testing.** Simplest option — add a
   button in `lesson_detail_screen.dart` (only shows if the lesson has a
   linked grammar exercise, but for now you can just hardcode it to test):

   ```dart
   import '../grammar/grammar_practice_screen.dart';

   // inside the ListView children, e.g. after the sign list:
   OutlinedButton.icon(
     onPressed: () {
       Navigator.of(context).push(
         MaterialPageRoute(
           builder: (_) => const GrammarPracticeScreen(
             exerciseId: 'grammar_hospital_help',
             mode: 'lesson',
           ),
         ),
       );
     },
     icon: const Icon(Icons.extension_outlined),
     label: const Text('Practice Grammar'),
   ),
   ```

5. **Run the app**, open "At the Hospital," tap "Practice Grammar," and try
   dragging the three tiles (Help / Doctor / Need) into the correct order.

## Swapping in real GIFs later

Replace `PLACEHOLDER_GIF` in the seed script (or edit the `gifUrl` field
directly in the Firebase console) with your own exported sign GIFs, uploaded
to Firebase Storage. Keep them small — aim for short (1–2 second) loops,
a few hundred KB each — since several may load on screen at once.

## Current sample curriculum

The app seeds sample content after the configured content-admin account signs
in. Seeding creates missing documents only; it does not overwrite existing
Firestore content. The seed currently provides 14 lessons and 12 sentence-order
exercises, using the existing sign vocabulary. The new lesson quizzes are
generated from each lesson's signs.

Deploy `firestore.rules` before seeding so the content admin can create grammar
exercises and learners can save their own grammar progress. The seeded sign
video/GIF URLs are demonstration placeholders, not verified FSL demonstrations;
replace them with reviewed teaching media before using the content as a
curriculum.

## Project plan: features needing attention

Camera-based sign recognition remains the project's main goal, using Google
MediaPipe Hands. Before camera development continues, stabilize the existing
lesson, quiz, and grammar experience so learners can complete those flows
without broken media, stuck loading states, or misleading controls.

### 1. Stabilize lesson and grammar flows before camera work

- [x] Link lesson details to their matching sentence-order exercise.
- [x] Add retryable error states for failed/timed-out grammar loading and
  progress saves; stop advertising grammar modes that are not implemented.
- [x] Fix the large sign tile sizing issue and add a widget regression test for
  the lesson quiz media area.
- [x] Add unit tests for sentence-order validation and correct tile ordering.
- [ ] Verify lesson loading, quizzes, GIF/video playback, and sign detail media
  on Android, including video retry and missing-media states.
- [ ] Verify grammar exercise loading, drag/drop, answer checking, reset, and
  progress-saving failure states on Android.
- [ ] Review lesson and grammar screens together for consistent spacing, colors,
  and controls that accurately reflect implemented functionality.
- [ ] Add regression tests for drag/drop interactions, answer recording, and
  loading/error recovery.

### 2. Build sign recognition on MediaPipe Hands

- [ ] Decide and document the first recognition scope: which FSL signs to
  recognize, whether they are static or moving signs, and what the app should
  display when a sign is uncertain or unrecognized.
- [ ] Integrate Google MediaPipe Hands with the camera pipeline and verify
  reliable hand landmark detection on supported Android devices.
- [ ] Define and test the landmark preprocessing and feature format passed from
  MediaPipe Hands to the sign classifier.
- [ ] Collect and label a representative FSL training/validation dataset with
  fluent reviewers. Include hand landmarks and, for moving signs, sequences over
  time; cover different signers and signing conditions, and confirm consent and
  usage rights.
- [ ] Train and evaluate an on-device sign classifier using the MediaPipe
  landmark representation; record accuracy, latency, and supported Android
  devices.
- [ ] Add the classifier model and label mapping to the app's documented
  asset/loading workflow, separate from MediaPipe Hands' hand-landmark
  detection.

### 3. Build the live camera experience

- [ ] Replace the camera placeholder with a live preview, camera permission
  handling, and clear permission-denied/unavailable states.
- [ ] Connect camera frames to MediaPipe Hands, then pass detected landmarks to
  the sign classifier; show the predicted sign, confidence/uncertainty, and a
  useful prompt when no hand or recognizable sign is detected.
- [ ] Handle camera lifecycle correctly, including pause/resume, switching or
  unavailable cameras, and releasing the camera when leaving the screen.
- [ ] Test recognition and responsiveness on real Android devices under varied
  lighting, backgrounds, and signing speeds; tune frame processing so preview
  remains responsive.
- [ ] Explain camera use to learners and keep recognition processing on-device
  unless a future, explicitly consented cloud workflow is designed.

### 4. Validate sign recognition

- [ ] Have fluent FSL reviewers verify the recognized labels and feedback, then
  replace demonstration GIF/video URLs with reviewed, permission-cleared
  teaching media.
- [ ] Add focused tests for landmark preprocessing, classifier input/output,
  low-confidence cases, permission states, and camera lifecycle/error handling.
- [ ] Run an end-to-end Android test: grant camera access, recognize in-scope
  signs, receive appropriate feedback for uncertain input, and navigate away
  and back without camera or app errors.

### 5. Continue supporting learning features

- [ ] Add a learner-facing entry point for standalone grammar test mode if it
  remains in scope.
- [ ] Verify lesson, quiz, and grammar progress flows, including save failures
  and retry states.
- [ ] Deploy and verify `firestore.rules`: learners can read learning content
  and write only their own progress; only the content admin can change content.
