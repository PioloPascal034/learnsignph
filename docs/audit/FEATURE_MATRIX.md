# LearnSign PH Feature Matrix

Statuses: COMPLETE means implemented and verified working by this audit; PARTIAL means real code exists but important scope is missing; BROKEN means intended functionality is failing; PLACEHOLDER means UI exists without the real feature; MISSING means no implementation was found; UNVERIFIED means source evidence exists but live/device/content verification was not possible.

| Area | Feature | Status | Evidence | Remaining work |
|---|---|---|---|---|
| Core | User registration | PARTIAL | auth/register_screen.dart, Firebase Auth, profile creation | Test configured Firebase, password policy, and profile-creation rollback. |
| Core | User login/logout | PARTIAL | login_screen.dart, FirebaseAuth, auth gate, sign-out actions | Verify configuration, errors, session restore, and all platforms. |
| Core | User profiles | PARTIAL | profile_screen.dart and account_settings_screen.dart | Verify image upload, validation, permissions, and persistence. |
| Core | Structured lessons | PARTIAL | lesson_model.dart, firestore_service.dart, lesson screens | Replace demo content and validate curriculum taxonomy/data. |
| Core | Alphabet lessons | MISSING | No alphabet-specific model, screen, or seed category | Add reviewed alphabet curriculum and media. |
| Core | Number lessons | MISSING | No number-specific implementation | Add reviewed number curriculum and media. |
| Core | Greetings/everyday vocabulary | PARTIAL | Seed lessons and categories exist | Content is placeholder/unverified; add reviewed media/translations. |
| Core | FSL video demonstrations | UNVERIFIED | SignVideoPlayer and remote videoUrl fields | Test playback and replace non-FSL media. |
| Core | Categorized modules | PARTIAL | Lesson category field and optional query | Add visible filters and taxonomy validation. |
| Core | Interactive quizzes | PARTIAL | Lesson quiz and grammar drag/drop | Add broader assessment analytics and verified answer content. |
| Core | Completion tracking | PARTIAL | Per-user lessonProgress writes | Prevent duplicate rewards and verify retry/cross-device consistency. |
| Core | Progress dashboard | PARTIAL | Dashboard reads points, level, lesson/sign counts, streak, badges | Verify calculations and loading/error states. |
| Core | Admin lesson management | PARTIAL | sign_gif_manager_screen.dart edits lessons/signs/media | Add complete exercise management, roles, audit trail, and navigation. |
| Gamification | XP | PARTIAL | addUserPoints and lesson/grammar rewards | Make rewards trusted, transactional, and idempotent. |
| Gamification | Learner levels | PARTIAL | calculateLevelFromPoints and dashboard | Secure source of truth and define thresholds. |
| Gamification | Achievement badges | PARTIAL | Badge checks and dashboard display | Secure awarding and test thresholds. |
| Gamification | Daily missions | MISSING | No mission model/service/screen | Design mission tracking. |
| Gamification | Learning streaks | PARTIAL | Streak update and dashboard/profile | Test dates, duplicate completions, timezone behavior. |
| Gamification | Unlockable lessons | MISSING | No prerequisites or gates | Add prerequisites and enforcement. |
| Gamification | Mini-games | MISSING | No implementation | Define scope and reward integration. |
| Gamification | Final chapter challenges | MISSING | No chapter/challenge flow | Add after core curriculum. |
| Gamification | Collectible sign dictionary | PARTIAL | Learned-sign dialogs and sign manager | Add standalone searchable collection/detail flow. |
| Interactive | Scenario-based learning | MISSING | No scenario model or screen | Add reviewed scenario content and state. |
| Interactive | Conversation simulator | MISSING | No simulator | Add dialogue/state model and content review. |
| Interactive | Story/campaign mode | MISSING | No campaign flow | Design after scenario MVP. |
| Interactive | School/hospital/restaurant/transport/emergency scenarios | PLACEHOLDER | Hardcoded labels and seed vocabulary only | Implement real scenarios and verify phrasing. |
| Interactive | Context-based sign selection | MISSING | No context-selection engine | Add choices and scoring. |
| Interactive | Correct/incorrect feedback | PARTIAL | Lesson and grammar result banners | Add explanatory/contextual feedback. |
| Interactive | Scenario completion tracking | MISSING | No scenario progress collection | Add per-user progress. |
| Adaptive | Weak-area identification | MISSING | No analytics/weakness aggregation | Store attempts by skill/category. |
| Adaptive | Personalized recommendations | MISSING | No recommendation service | Define deterministic recommendation rules/UI. |
| Adaptive | Quiz performance analytics | PARTIAL | Local lesson answers; grammar attempts persisted | Store question-level attempts and timestamps. |
| Adaptive | Difficulty progression | MISSING | difficulty is metadata only | Add progression rules and enforcement. |
| Adaptive | Review/retry activities | PARTIAL | Quiz retry, grammar reset, video retry | Add targeted review sets/history. |
| Accessibility | Keyboard/mouse navigation | UNVERIFIED | Flutter controls and desktop target exist | Perform Windows keyboard/focus/drag-drop checks. |
| Accessibility | Responsive desktop layouts | UNVERIFIED | Mostly mobile-oriented layouts | Test multiple Windows sizes and fix overflow/navigation. |
| Accessibility | Typography/feedback | PARTIAL | Theme and basic loading/error/result controls | Run contrast, semantics, font-scaling, and copy review. |
| Accessibility | Video playback controls | PARTIAL | video_player initialization/looping; chewie unused | Add play/seek/volume/fullscreen controls and verify platforms. |
| Quality | Verified FSL representation | MISSING | No citations, review metadata, consent, or validated assets | Obtain authoritative references and Deaf-community review. |

## Overall rating

Verified complete at source/build level: Dart models, static analysis, the focused unit/widget suite, and web compilation. No requested product feature should be called fully complete until live Firebase, media, and platform flows are exercised.
