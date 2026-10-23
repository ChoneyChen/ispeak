# Daily recall, reinforcement and scheduling

Updated 2026-10-23. These are iSpeak's own transparent rules, not a reconstruction of another product's private algorithm or a claim of a measured retention probability.

## What the public sources support

- [百词斩官网](https://baicizhan.com/): describes daily review planning informed by the forgetting curve. Its [App Store description](https://apps.apple.com/cn/app/id557545298) also describes a configurable study plan and several retrieval formats.
- [不背单词官网](https://www.bbdc.cn/): describes adapting study arrangements to memory results. The [developer's App Store description](https://apps.apple.com/cn/app/id698570469) emphasizes contextual examples and planned anti-forgetting review. Neither source publishes the complete scheduler or parameter values.
- [Anki's official deck-options manual](https://docs.ankiweb.net/manual/deck-options): documents separate daily limits, mixing new and review cards, learning/relearning steps, prioritizing overdue material and difficulty-dependent intervals. These provide a public reference for scheduling mechanics; iSpeak does not implement or claim to use FSRS.

The following choices are iSpeak implementation decisions adapted to sentence recall.

## Original study remains separate

The Study entry still resumes the first unlearned sentence in course order. A grammar section releases recall only after all its example IDs are learned. Daily goals do not block this entry, mark unseen material learned, or change sentence IDs, content or the app's bundle identity. Library preview never counts as study.

Daily defaults are 10 new sentences and 30 old reviews. New study and first recall are displayed separately, sharing the new-sentence goal. Newly unlocked sentences that have never passed recall form the initial-recall pool; previously recalled due sentences form the review pool.

## Daily selection and progress

- Admit at most the day's new/review allowance; persist admitted IDs so relaunch does not refill the quota or reshuffle the selection.
- Default order is two old reviews then one new initial recall, repeating until either pool runs out. Users can choose reviews first.
- Sort overdue reviews before later due dates; reinforcement takes priority when eligible. Stable course order breaks ties.
- Goals reset at the local calendar boundary. Unfinished admitted cards and overdue work remain eligible for the next day's selection, never falsely completed.
- A lower goal does not discard cards already admitted that day. Explicit extra practice adds five initial-recall places and ten review places. The remaining backlog stays visible outside the daily allowance.
- Count unique completed sentences, not every retry. Wrong or hard initial recall stays incomplete while short-term work remains.

## Feedback and intervals

An unrevealed card contains only the Chinese cue and neutral status. English, grammar hints and speech appear after reveal. Self-assessment checks meaning and grammar, not exact wording.

| Feedback | State change |
| --- | --- |
| Incorrect | Retain error history; reduce interval level by two, require two separated correct recalls, first retry after 60 seconds **or** two other accepted answers |
| First retry correct | One confirmation remains; retry after 10 minutes **or** two other accepted answers |
| Final retry correct | Leave reinforcement and schedule for the next local day |
| Hard initial / reinforcement | Keep at least one confirmation outstanding; retry after 5 minutes **or** two other accepted answers |
| Hard mature review | Move down one interval level and schedule from the actual answer day |
| Normal correct | First success uses one day; later successes advance through 1 / 3 / 7 / 14 / 30 / 60 / 120 / 180 calendar days |
| Mastered / 斩 | Permanently exclude from automatic recall, retain library content |

A repeated correct response is rejected while an ordinary card is not due. The longest interval stays at 180 days rather than silently retiring new cards after day 30. Calendar-day arithmetic starts from the actual answer day, so late reviews do not trigger several already-past checkpoints in a row. These are spaced repetition defaults, not a universal optimal memory curve.

Retries are inserted after two other queued cards; an ineligible retry waits while other eligible cards run. With nothing else ready, show a waiting screen and allow exit. Persist cooldown timestamps and answer sequence numbers so exiting/relaunching cannot skip the separation requirement. The two alternatives allow short sessions to finish through intervening retrievals without forcing idle countdowns.

## v1 migration and reminders

Upgrade progress schema 1 to 2 in place, with an exact-byte backup before overwriting the old progress. Keep all learned IDs, legacy due dates, permanent cuts and already completed legacy cycles. Active old records adopt feedback scheduling only after their next answer. If backup fails, still display valid loaded progress, protect the original file, and explain the save limitation.

Native reminders are optional local notifications, not server push. Ask system permission only when the user enables the switch. Prepare at most 60 useful reminder dates within the next year, including known due dates beyond the first week; schedule at most one reminder per day, refresh as progress/time/foreground state changes, remove unnecessary requests, and omit private sentence text from notification bodies. OS permission and system notification settings control delivery. The webpage does not promise background local reminders.

Swift and web versions share the same interval ladder, quotas, mix, retry gates, migration invariants and acceptance tests. Both keep the curriculum and original study order intact.
