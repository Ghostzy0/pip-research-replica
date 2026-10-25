This repository exports one runnable executable: ResearchBaseline. Tests exercise the shared core and desktop code included here; other edition entry points are excluded.

# Verification and known limits

## Current source status — 25 October 2026

Qualification 10 completed 96 cases: 93 passed, 3 opt-in live-writer cases skipped, 0 failed. All four products passed local build/package checks. Qualification 9 and both exact Q9 public heads also passed their 91-case checks (88 passed, 3 skipped, 0 failed). Q10 hosted CI and the v7 packaged native checks remain pending; these results do not establish release approval or full reference parity.

The Q8 source policy kept each Notes scene bound to its captured notebook and allowed one editor owner per notebook. It used SwiftUI's [`presentationPreventsAppTermination(false)`](https://developer.apple.com/documentation/swiftui/view/presentationpreventsapptermination(_:)) on macOS 15.4+ with Swift 6.1+, and a scoped, restoring [AppKit modal-window setting](https://developer.apple.com/documentation/appkit/nswindow/preventsapplicationterminationwhenmodal) on macOS 14–15.3 and earlier compiler versions. That is historical Q8 source behavior; it did not pass the later native quit gate.

Q9 source gates termination ingress before `super.terminate` can tear down Notes sheets. A principal-class subclass installs early at startup and provides a typed bridge. A guarded one-shot approval covers the native delegate query; direct system queries use `terminateLater` and one reply. Unavailable active Notes sessions and dirty `.close` requests fail closed; pre-model startup can terminate before any Notes session exists. Thirteen Q9 source regressions cover delegate and ingress paths. Both exact Q9 public heads passed hosted CI; current Q10 hosted CI and v7 native checks remain pending.

## Native observations

A native slice on the exact Q7/v4 Pip package exercised editing and reopening an existing synthetic note and observed Done, Cancel, and Save. The saved note remained after restart, and clean main-window Quit exited normally. Dirty Cmd-Q and enabled app-menu Quit produced no alert; immediate PID checks confirmed the same process remained alive. This is the Q7/v4 dirty-quit result. In a later bounded Q8 native slice, dirty Cmd-Q and menu Quit both exited without a prompt. Reopening offered recovery; restoring it recovered the edited synthetic draft while the saved library remained unchanged. Recovery retained the edit, but neither quit route offered Save/Discard/Cancel, so the Q8 native dirty-quit gate failed.

For all four Q9 packaged variants, startup and dirty Cmd-Q handling passed: Cancel kept the app open, while Save preserved the edit after restart. Pip Core also passed the app-menu Discard and restart route. Neutral Plus editing/export mechanics passed, but fact-bearing retrieval failed: its answer and excerpt cited title spans 0:45 and 0:44 while omitting 18:00 and 19:00, even after the full originals were opened. This shared retrieval issue is tracked in [public issue #6](https://github.com/ghostzy0/pip-research/issues/6). Q10 Core retrieval qualification passed locally, but hosted Q10 CI and v7 native checks are pending. The overall release remains on hold.

One bounded native SIGTERM recovery flow from 23 October restored and saved a synthetic Unicode note. That does not cover ordinary window close, quit coordination, concurrent scenes, failed saves, or general crash recovery.

## Local writer evidence

An earlier bounded synthetic probe with the pinned Qwen3 1.7B returned valid JSON with citation IDs and identified a conflict, but misleadingly interpreted source/revision dates. In a separate opt-in production-model run, conflict-plus-persistence and hostile-source passed. The absent-fact case failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that holiday information was absent. It did not explicitly invent a holiday time. This does not establish general grounding or broad product persistence. The writer remains optional, experimental, and off by default. A bounded raw Qwen3.5 0.8B comparison repeated the missing-support failure and was not adopted; no further model comparisons are part of this release review.

## Historical evidence

The 23 October alpha releases and their test/package receipts describe their own source and packages. The qualification-4 and hosted 77-pass/3-skip results are historical for earlier source; hosted 82-pass/3-skip CI qualifies Q7 only. Neither establishes native Q8 behavior. No current public `0.1.2`/`0.2.1` release has been published or verified in this documentation update.

The earlier suite and four builds were exercised on the project's Apple-silicon development host. macOS 14 and Intel runtime behavior, VoiceOver, reduced-motion human review, and full NotebookLM/Gemini Notebook parity remain unverified. A build, signature, fixture, or static privacy scan does not establish those outcomes.
