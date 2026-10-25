This repository exports one runnable executable: ResearchBaseline. Tests exercise the shared core and desktop code included here; other edition entry points are excluded.

# Verification and known limits

## Current source status — 25 October 2026

Qualification 8 completed 87 cases: 84 passed, 3 opt-in live-writer cases skipped, 0 failed. ResearchCore had 46 passes; ResearchDesktop had 41 cases, including the three skips (38 passed). All four products built, passed ad-hoc signature verification, and passed resource and private-path checks; source and resources were unchanged during the recorded run, 06:24:16–06:24:44 UTC. Test log SHA-256: `d5f0029ddcac35284db741cf30e768b6a14fd4b988bdef52c3cd907032934827`. The hosted 82-pass/3-skip result qualifies Q7 only. Fresh hosted CI for the exact Q8 public payload remains outstanding.

The Q8 Notes source keeps each scene bound to its captured notebook and permits one editor owner per notebook. It lets termination ingress through the Notes sheet reach the existing Save/Discard/Cancel coordinator. On macOS 15.4+ with Swift 6.1+, it uses SwiftUI's [`presentationPreventsAppTermination(false)`](https://developer.apple.com/documentation/swiftui/view/presentationpreventsapptermination(_:)); on macOS 14–15.3 and earlier compiler versions, a scoped helper changes and restores only the Notes sheet's [AppKit modal-window setting](https://developer.apple.com/documentation/appkit/nswindow/preventsapplicationterminationwhenmodal). The Q7 coordinator and its guarded one-shot reentry remain in place. This describes source behavior, not packaged UI acceptance.

## Native observations

A native slice on the exact Q7/v4 Pip package exercised editing and reopening an existing synthetic note and observed Done, Cancel, and Save. The saved note remained after restart, and clean main-window Quit exited normally. Dirty Cmd-Q and enabled app-menu Quit produced no alert; immediate PID checks confirmed the same process remained alive. This confirms the dirty-quit failure on Q7/v4. Q8's termination-ingress source has not been run natively, so its behavior remains unverified.

One bounded native SIGTERM recovery flow from 23 October restored and saved a synthetic Unicode note. That does not cover ordinary window close, quit coordination, concurrent scenes, failed saves, or general crash recovery.

## Local writer evidence

An earlier bounded synthetic probe with the pinned Qwen3 1.7B returned valid JSON with citation IDs and identified a conflict, but misleadingly interpreted source/revision dates. In a separate opt-in production-model run, conflict-plus-persistence and hostile-source passed. The absent-fact case failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that holiday information was absent. It did not explicitly invent a holiday time. This does not establish general grounding or broad product persistence. The writer remains optional, experimental, and off by default. A bounded raw Qwen3.5 0.8B comparison repeated the missing-support failure and was not adopted; no further model comparisons are part of this release review.

## Historical evidence

The 23 October alpha releases and their test/package receipts describe their own source and packages. The qualification-4 and hosted 77-pass/3-skip results are historical for earlier source; hosted 82-pass/3-skip CI qualifies Q7 only. Neither establishes native Q8 behavior. No current public `0.1.2`/`0.2.1` release has been published or verified in this documentation update.

The earlier suite and four builds were exercised on the project's Apple-silicon development host. macOS 14 and Intel runtime behavior, VoiceOver, reduced-motion human review, and full NotebookLM/Gemini Notebook parity remain unverified. A build, signature, fixture, or static privacy scan does not establish those outcomes.
