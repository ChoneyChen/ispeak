# Reusable native app architecture

## Stable code, replaceable data

`assets/ios-template` contains the working SwiftUI application. No hosted backend, account system or model API is required at runtime. The invoking AI writes the private curriculum during creation; the installed app reads local JSON. The shared public package contains no author's personal PDF, individual 700-sentence corpus, Apple team, certificate, profile or phone identifier.

| Layer | Responsibility | Personalization |
|---|---|---|
| `curriculum.json` | Chapters, grammar, bilingual examples, provenance, reference texts, PDF pages | User-specific content |
| `Curriculum.swift` | Decode/validate stable models, expose counts | Data-driven counts |
| `LearningStore.swift` | Learn, unlock, due dates, mastery, atomic persistence | Same rules for every user |
| `StudyHomeView`, `LearningSessionView` | Resume, one-card study, left swipe, section completion | Same UI, supplied sentences |
| `ReviewViews` | Chinese-only cue, reveal, self-grade, error rotation | Same state machine |
| `LibraryViews` | Search, preview, references, optional PDF | Reads the user's content |
| `DesignSystem.swift` | Warm paper, forest/lime palette, spring, haptics, speech | Shared reusable design |

The application has Study, Recall and Library entries. Read-only library preview never advances learning. Grammar sections contain five examples. Bundle identifiers isolate different app installations and their local progress. A profile file is not copied into the app, but personalized text in the curriculum is still personal data.

## State machine invariants

- Each accepted learn action saves synchronously before its visual exit. Relaunch resumes at the first unlearned sentence.
- A grammar section is locked for recall until all five example IDs are learned. Completing the section releases all five, not just the last one.
- A recall session snapshots current due items. The answer is absent from the pre-reveal view hierarchy; no English grammar pattern or English speech button leaks it.
- Incorrect leaves the persisted due date, anchor and review stage unchanged, then rotates the sentence to the session's tail. It can be revisited or the user can leave and return later.
- The first correct answer establishes the anchor. Subsequent targets are **anchor + 7 / +14 / +30 calendar days**, not 7+14+30 days from each last answer. Calendar arithmetic preserves local wall-clock time across daylight saving changes.
- Review stages: 0 initial → 1 waiting day 7 → 2 waiting day 14 → 3 waiting day 30 → 4 complete. Passing day 30 finishes the automatic cycle. Mastered/斩 is a separate permanent exclusion state.
- Overdue checkpoints remain due. If a very late answer advances to another already-past checkpoint, the item remains due when the home page rechecks; it is not silently skipped to “complete”. The UI explains dates from the first correct answer.
- Mastered excludes the item forever unless the user explicitly resets progress. It remains readable in the library.
- Saves use atomic file writes. Corrupt input is kept and protected from overwrite; save errors appear inside full-screen sessions as well as on the root screen. A recoverable write error offers retry.

Default persisted file: the app sandbox's Application Support/iSpeak/progress.json. UI tests use a separate iSpeakUITests/progress.json selected by launch arguments. Never point tests at a real user's progress file.

## Interaction details already solved

The card's drag only advances when horizontal motion dominates and the left threshold/prediction is met. Vertical scrolling of long explanations does not count as learning. Separate interaction lock from opacity/offset; otherwise the card vanishes before the spring can be seen. Dynamic text may scroll inside the card. Reduced Motion disables the main transitions. Native AVSpeechSynthesizer provides English speech where an OS voice is available; no microphone permission is needed.

Generated/source PDF is optional. `render_book.py --pdf` produces both Guide.pdf and a newly paginated curriculum.json. The app uses those page anchors and PDFKit; it hides all source controls when Guide.pdf is absent. Do not show a missing-file button for an HTML-only export.

## Build and signing

The project uses Xcode synchronized folders (requires a compatible Xcode) and an iOS 17 deployment target. This release is validated with local Xcode 27.1; do not treat a simulator build as proof of compatibility with untested SDK versions.

`project.py` selects an available iPhone simulator, preferring 14 Pro when available; users can override by simulator name/ID. Nothing in the public template points to an author's simulator. `build --unsigned-device` verifies generic device architecture without signing or installation.

Physical install uses the connected user's device, their own team and a unique bundle ID. The user's request must authorize installation. `project.py install` requires explicit device/team parameters and refuses the example bundle namespace. Xcode manages provisioning, certificates and any credential prompts locally; those materials never enter the template. Read back the installed bundle and launch result. Developer signing may expire; report the actual provisioning expiration if relevant, without promising indefinite installation.

For existing applications, keep bundle identity and sentence IDs stable; do not uninstall an app just to install an update because that can remove its progress. Do not bundle test progress, logs, DerivedData or signing artifacts into an open-source release.
