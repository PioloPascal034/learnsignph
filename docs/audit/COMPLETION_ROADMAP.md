# LearnSign PH Completion Roadmap

The Windows desktop version remains the immediate target. Estimates are engineering time for one developer and exclude external content review, account configuration, and media production.

## P0 — Critical MVP

| Task | Affected modules | Dependencies | Difficulty | Estimate | Acceptance criteria |
|---|---|---|---|---:|---|
| Fix Windows Firebase/CMake build | windows/, FlutterFire/plugin lockfile, local toolchain | Confirm supported CMake/plugin combination | Medium | 0.5–1 day | flutter build windows completes and launches. |
| Secure profile writes and rewards | firestore.rules, firestore_service.dart, auth/backend rules | Decide trusted reward authority | High | 1–2 days | Rules tests show profile-only updates; rewards cannot be forged; completion is idempotent. |
| Validate auth/profile lifecycle | main.dart, auth/, profile/, rules | Firebase project and test accounts | Medium | 0.5–1 day | Register, login, logout, session restore, edit, and recovery work on Windows/Android. |
| Replace seed placeholders with reviewed curriculum | firestore_seed.dart, Firestore content, media manager | FSL experts, consent, licensed media | High/external | 2–5+ days | Every released sign has reviewed media/source metadata; no demo URLs remain. |
| Harden lesson flow | lesson screens/services/models | Real lesson data | Medium | 1 day | List/detail/empty/error/media/quiz/progress flow works and completion saves once. |
| Make grammar catalog data-driven | main_navigation_screen.dart, grammar service/screens | Existing grammar documents | Medium | 0.5–1 day | Hub shows only available exercises and missing ones do not dead-end. |
| Add integration/rules tests | test/, emulator config | Test data/emulator | Medium | 1–2 days | Auth, completion, duplicate submission, grammar save, and rules cases are automated. |

P0 deliverable: a presentable Windows MVP with real reviewed content, secure progress, working auth, lessons, quizzes, grammar, and profile flows.

## P1 — Important product differentiation

| Task | Affected modules | Dependencies | Difficulty | Estimate | Acceptance criteria |
|---|---|---|---|---:|---|
| Scenario engine: school, hospital, restaurant, transport, emergency | New scenario models/services/screens and rules | Reviewed scripts/media | High | 3–5 days + content | Context selection, answer feedback, and completion persist. |
| Real progress analytics | progress models/services/dashboard | Question-level events | Medium | 2–3 days | Attempts, scores, categories, weak areas, and retry history are persisted. |
| Secure gamification | backend/rules, profile/dashboard | P0 reward authority | High | 2–4 days | XP, levels, badges, streaks, and unlocks are idempotent and explainable. |
| Searchable sign dictionary | sign service/screens/models | Complete reviewed sign catalog | Medium | 1–2 days | Search/filter, media detail, learned/collection state work. |
| Adaptive review/recommendations | analytics/recommendation service/UI | P1 analytics | Medium/high | 2–4 days | Weak categories produce deterministic review recommendations. |
| Desktop accessibility pass | all screens, navigation, grammar | Windows build fixed | Medium | 1–2 days | Keyboard focus, resize, readable scaling, semantics, and drag/drop alternatives pass. |

## P2 — Enhancements

- Daily missions and richer achievements: 2–4 days after reward authority exists.
- Story/campaign chapters and final challenges: 1–2 weeks plus content production.
- Mini-games: 3–7 days per game mode plus scoring integration.
- Camera and MediaPipe recognition: multi-week effort requiring scope, dataset, consent, model evaluation, Android performance testing, and Deaf-community validation. It is not a same-day MVP task.
- Visual polish, localization, offline caching, and advanced analytics: schedule after reliability and content validation.

## Recommended order

1. Resolve the Windows build blocker.
2. Lock down Firestore/Storage authorization and idempotent rewards.
3. Load a small reviewed curriculum slice: greetings, alphabet/numbers, and one practical scenario.
4. Verify auth → lessons → media → quiz → progress on Windows and Android.
5. Make grammar availability data-driven and test failure/retry.
6. Add scenario learning and analytics.
7. Add secure gamification, dictionary, and adaptive review.
8. Treat camera recognition and campaign-scale content as separate projects.

## What can be completed today

Code-side P0 work can begin today: Windows diagnosis, rules/reward design, auth/lesson/grammar integration tests, and removal of dead-end UI paths. Replacing media, validating FSL semantics, and approving content cannot be completed responsibly without reviewed assets and Deaf-community participation.
