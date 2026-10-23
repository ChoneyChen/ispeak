# Delivery and checks

## Required evidence, scaled to the output

1. Validate all chapter files and the assembled curriculum with the user's profile. Default full mode must be 28 chapters / 140 points / 700 unique bilingual examples, in the expected order.
2. Do the semantic checks in profile-and-content.md. Structural and fact-reference validation alone cannot certify truth, grammar or translation.
3. Render HTML/Markdown; when generating PDF, inspect the cover, first grammar page, at least one long example, a late chapter, and any long appendix. Check Chinese glyphs, line wrapping, page breaks and page-map values. The native renderer keeps an example pair together and continues large appendices across pages.
4. Run the core harness: unlock only after five learned, daily budgets and mixing, local-day rollover, separated two-step reinforcement, hard ratings, adaptive interval boundaries, calendar/DST behavior, mastery, legacy migration/backup, restart/resume, invalid submissions, atomic writes and protected corrupt input.
5. Compile the generated app. Exercise an actual horizontal swipe and a mostly vertical drag, exit/relaunch mid-course, complete a section, reveal a Chinese-only recall, get one wrong and confirm both separated retries, rate hard, master, change and persist the daily plan, check large-text controls, relaunch, search, preview without marking learned, and open the correct PDF page when present. The included XCUITests cover these routes with an isolated store. They assume at least two grammar sections, a five-example first section and G001, as in the default framework/demo. For a custom imported book with different groups, adapt those UI expectations or exercise the equivalent paths manually.
6. Inspect the actual iPhone-sized screenshots. Record the device model/runtime used. Do not describe screenshots as proof of animation feel; check a live swipe or motion capture when polishing motion.

Tests live in the template's Tests folder. The Python pipeline tests in the skill's tests folder cover malformed data, provenance references, the full shared catalog, assembly, scaffolding, no implicit overwrites, arbitrary working directories and public packaging boundaries.

## Output folder

A useful generated layout:
```
learner-work/
  profile.private.json        private fact ledger
  content-plan.json           private authoring plan
  chapters/                  AI-authored chapter files
  curriculum.json            validated private corpus
  Book/                      guide.html, guide.md, optional Guide.pdf, matching curriculum.json
  iSpeakApp/                 runnable native source
  qa/                        validation evidence and selected screenshots
```
Do not copy these files into the installed skill's assets. A folder called “demo” is only non-personal if its actual content is fictional, not because of its filename.

## Handoff

Tell the user what they can do now and link the actual local files. Separate generated, compiled, simulator-tested, device-installed and launched states. If no Xcode is available, deliver the source and content with the exact next build command rather than suggesting the app has run. If the user asks for installation, continue to the physical installation unless a real signing/device/OS prompt blocks it; ask only for the necessary action at that point.

## Public release

The framework's MIT license covers the included code and generic instructional resources. New user-provided or third-party source materials retain their own rights; do not claim the MIT license makes an imported copyrighted PDF redistributable.

Use package_release.py to create a ZIP and checksum. It only includes the entrypoint, agents, scripts, references, assets, tests and licensing/readme files; it rejects symlinks, signing artifacts, private-profile filenames, obvious user-home paths, emails and physical-device IDs. This is a useful guard, not a general anonymization proof. Review the actual archive file list and ensure no private user sentences, screenshots or source PDFs were added to public assets.

Publishing to a hosting service or creating a public repository is a separate external action. Prepare a reviewable clean package first; publish only when the user's request clearly authorizes the destination/action. Do not infer a GitHub account, repository or public visibility from “create a skill”.
