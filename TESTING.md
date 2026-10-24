This repository exports one runnable executable: ResearchBaseline. Tests exercise the shared core and desktop code included here; other edition entry points are excluded.

# Verification and known limits

## 24 October 2026 source and package qualification

The qualification-3 default Swift suite completed **76 cases: 73 passed, 3 opt-in live-writer cases skipped, 0 failures**. ResearchCore had 46 passing cases; ResearchDesktop had 30 cases, including the three skips (27 passed). Separately, the opt-in production-model run passed the conflict-plus-persistence case and the hostile-source case. The absent-fact case failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` It did not explicitly invent holiday hours, but failed to acknowledge that the source gives weekday hours only and no public-holiday information. This follow-up does not alter the default-suite result.

All four declared release products were built and passed ad-hoc signature verification and private-path string scans in the same qualification batch. This establishes the stated build/package checks on the tested host, not final public export review, a fresh public clone, UI behavior, VoiceOver, or release acceptance. The current packages contain the frozen bundled AI setup and local-drafting resources. Final profile-specific resource repackaging and export/package checks remain; no Swift rebuild is implied by that step.

The manual-notes source includes per-notebook editor ownership, with the scene retaining its captured notebook target so an editor does not silently switch when another scene changes selection. Application quit now coordinates explicit Save, Discard, or Cancel decisions across open note editors, and waits for save/recovery completion before terminating. The callback and state tests do not establish that the native SwiftUI alerts, scene/window lifecycle, or Cmd-Q behave correctly in the packaged app. Dirty-modal Cmd-Q previously had no visible response; regression acceptance in the current packages remains pending. Do not describe Notes close/quit as natively accepted until the packaged flows have been exercised.

One bounded native SIGTERM recovery flow from 23 October restored and saved a synthetic Unicode note. That does not cover ordinary window close, quit coordination, concurrent scenes, failed saves, or general crash recovery. Exact scenarios still needed include same-notebook editor ownership across scenes, distinct notebooks in separate scenes, Save/Discard/Cancel, repeated quit, pending writes, failure/cancel recovery, and reopening after quit.

## Local writer evidence

An earlier bounded synthetic probe with the pinned Qwen3 1.7B returned valid JSON and the required citation IDs in 2.739 seconds. It identified both conflicting values and their disagreement, but also gave a misleading interpretation of source/revision dates as dates for those values. In a separate opt-in production-model run, the conflict-plus-persistence and hostile-source cases passed; the absent-fact test failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that the source only gives weekday hours. It did not explicitly invent holiday hours. One synthetic persistence scenario therefore passed, while broader grounding and persistence remain unverified. The writer remains optional, experimental, and off by default. A bounded raw comparison with the already-installed Qwen3.5 0.8B repeated the missing-support failure and was not adopted; no further model comparisons are part of this release review. The independent validator remains strict; rejected drafts must not be presented as evidence.

## Earlier evidence is historical

The 23 October alpha releases and their build/test receipts describe their own source and packages; they do not qualify the resumed 24 October source. Historical test counts, package hashes, CI runs and native smoke results must remain labelled with their actual date/build. No current public `0.1.2`/`0.2.1` release has been published or verified in this documentation update.

The suite and four builds were exercised on the project’s Apple-silicon development host. macOS 14 and Intel runtime behavior, VoiceOver, reduced-motion human review, and full NotebookLM/Gemini Notebook parity remain unverified. A build, signature, fixture, or static privacy scan does not establish those outcomes.
