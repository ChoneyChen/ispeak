# Reusable native app architecture

## Stable code, replaceable data

`assets/ios-template` contains the working SwiftUI application. No hosted backend, account system or model API is required at runtime. The invoking AI writes the private curriculum during creation; the installed app reads local JSON. The shared public package contains no author's personal PDF, individual 700-sentence corpus, Apple team, certificate, profile or phone identifier.

| Layer | Responsibility | Personalization |
|---|---|---|
| `curriculum.json` | Chapters, grammar, bilingual examples, provenance, reference texts, PDF pages | User-specific content |
| `Curriculum.swift` | Decode/validate stable models, expose counts | Data-driven counts |
| `LearningStore.swift` | Learn, unlock, due dates, mastery, atomic persistence | Same rules for every user |
| `StudyHomeView`, `LearningSessionView` | Resume, one-card study, left swipe, section completion | Same UI, supplied sentences |
| `ReviewViews` | Daily plan, mixed recall, reveal, self-grade, reinforcement | Same state machine |
| `LibraryViews` | Search, preview, references, optional PDF | Reads the user's content |
| `DesignSystem.swift` | Warm paper, forest/lime palette, spring, haptics, speech | Shared reusable design |

The application has Study, Recall and Library entries. Read-only library preview never advances learning. Grammar sections contain five examples. Bundle identifiers isolate different app installations and their local progress. A profile file is not copied into the app, but personalized text in the curriculum is still personal data.

## State machine invariants

- Save an accepted study/grade action before its visual transition; resume study at the first unlearned ID.
- Unlock a section's recall only after every example is learned. Library preview does not mark learning complete.
- Recall starts with Chinese only; reveal unlocks English, grammar details, self-grading and speech.
- Daily targets, admitted cards, unique completions, retries and settings persist. New/old mixing and review-first ordering use the same engine.
- Incorrect answers need two separated confirmations. Hard answers reduce the interval or retain short-term work. Never show a waiting retry as completed.
- Feedback scheduling uses calendar days from each actual successful answer. Legacy 7/14/30 dates, already completed cycles and cuts survive migration; new cards continue longer-term review.
- Mastered permanently excludes the item, while preserving library access.
- Upgrade to schema 2 only after backing up v1 bytes. Corrupt input and failed backups protect the original file; recoverable writes expose a retry.

Read [recall-design.md](recall-design.md) for daily caps, mixing, exact retry gates, interval parameters, source research and migration. Do not reintroduce the old fixed-anchor schedule when modifying current apps.

Default persisted file: the app sandbox's Application Support/iSpeak/progress.json. UI tests use isolated iSpeakUITests/progress.json. Never point tests at a user's real progress.

## Interaction details already solved

The card's drag only advances when horizontal motion dominates and the left threshold/prediction is met. Vertical scrolling of long explanations does not count as learning. Separate interaction lock from opacity/offset; otherwise the card vanishes before the spring can be seen. Normal phone cards use fitting layouts with fixed actions. Long content and accessibility text may scroll inside the card; do not truncate the actual sentence to force a fit. Reduced Motion disables the main transitions. Native AVSpeechSynthesizer provides English speech where an OS voice is available; no microphone permission is needed.

Generated/source PDF is optional. `render_book.py --pdf` produces both Guide.pdf and a newly paginated curriculum.json. The app uses those page anchors and PDFKit; it hides all source controls when Guide.pdf is absent. Do not show a missing-file button for an HTML-only export.

Optional native local reminders are handled by `ReminderManager.swift`. Request notification permission only after the user enables reminders; never put private examples in notification text.

## Build and signing

The project uses Xcode synchronized folders (requires a compatible Xcode) and an iOS 17 deployment target. This release is validated with local Xcode 27.1; do not treat a simulator build as proof of compatibility with untested SDK versions.

`project.py` selects an available iPhone simulator, preferring 14 Pro when available; users can override by simulator name/ID. Nothing in the public template points to an author's simulator. `build --unsigned-device` verifies generic device architecture without signing or installation.

Physical install uses the connected user's device, their own team and a unique bundle ID. The user's request must authorize installation. `project.py install` requires explicit device/team parameters and refuses the example bundle namespace. Xcode manages provisioning, certificates and any credential prompts locally; those materials never enter the template. Read back the installed bundle and launch result. Developer signing may expire; report the actual provisioning expiration if relevant, without promising indefinite installation.

For existing applications, keep bundle identity and sentence IDs stable; do not uninstall an app just to install an update because that can remove its progress. Do not bundle test progress, logs, DerivedData or signing artifacts into an open-source release.
