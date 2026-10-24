This repository exports one runnable executable: ResearchBaseline. Tests exercise the shared core and desktop code included here; other edition entry points are excluded.

# Verification and known limits

## Current source status — 24 October 2026

Qualification 7 completed 85 cases: 82 passed, 3 opt-in live-writer cases skipped, 0 failed. ResearchCore had 46 passes; ResearchDesktop had 39 cases, including the three skips (36 passed). All four products built, passed ad-hoc signature verification, and passed private-path checks; source and resources were unchanged during the recorded run, 19:12:55–19:13:17 UTC. The hosted 77-pass/3-skip result qualifies the earlier AppKit bridge only. Fresh hosted CI against the current public payload remains outstanding.

The current Notes source keeps each scene bound to its captured notebook and permits one editor owner per notebook. Normal termination uses AppKit's immediate cancel response while the asynchronous Save/Discard/Cancel coordinator runs on the normal run loop. The source permits one guarded termination reentry only when model identity, session revision, and the empty session registry still match. It does not use a `terminateLater`/reply guarantee. This describes source behavior, not packaged UI acceptance.

## Native observations

A narrow native slice on the previous qualification-4 packaged candidate exercised synthetic Notes create/save/edit/reopen and observed Done, Cancel, and Save. Dirty Cmd-Q and an enabled menu Quit produced no prompt. The process ID was not checked at the time, so whether the app had quit is unresolved and the cause is unproven. This slice is not quit acceptance. The current termination-coordination source has not been run natively.

One bounded native SIGTERM recovery flow from 23 October restored and saved a synthetic Unicode note. That does not cover ordinary window close, quit coordination, concurrent scenes, failed saves, or general crash recovery.

## Local writer evidence

An earlier bounded synthetic probe with the pinned Qwen3 1.7B returned valid JSON with citation IDs and identified a conflict, but misleadingly interpreted source/revision dates. In a separate opt-in production-model run, conflict-plus-persistence and hostile-source passed. The absent-fact case failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that holiday information was absent. It did not explicitly invent a holiday time. This does not establish general grounding or broad product persistence. The writer remains optional, experimental, and off by default. A bounded raw Qwen3.5 0.8B comparison repeated the missing-support failure and was not adopted; no further model comparisons are part of this release review.

## Historical evidence

The 23 October alpha releases and their test/package receipts describe their own source and packages. The qualification-4 and hosted 77-pass/3-skip results are also historical for the earlier AppKit bridge; they do not qualify the current termination-coordination source. No current public `0.1.2`/`0.2.1` release has been published or verified in this documentation update.

The earlier suite and four builds were exercised on the project's Apple-silicon development host. macOS 14 and Intel runtime behavior, VoiceOver, reduced-motion human review, and full NotebookLM/Gemini Notebook parity remain unverified. A build, signature, fixture, or static privacy scan does not establish those outcomes.
