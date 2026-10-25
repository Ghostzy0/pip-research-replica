# Review and qualification record

**Updated 25 October 2026.** Qualification 8 completed 87 cases: 84 passed, 3 opt-in live-writer cases skipped, 0 failed. ResearchCore had 46 passes; ResearchDesktop had 41 cases, including the three skips (38 passed). All four products built, passed ad-hoc signature verification, and passed resource and private-path checks; source and resources were unchanged during the recorded run, 06:24:16–06:24:44 UTC. Test log SHA-256: `d5f0029ddcac35284db741cf30e768b6a14fd4b988bdef52c3cd907032934827`. The hosted 82-pass/3-skip result qualifies the earlier Q7 implementation only. Fresh hosted CI against the Q8 public payload remains outstanding.

The current source keeps each Notes scene bound to its captured notebook, allows one editor owner per notebook, and retains interrupted-edit recovery. Notes sheets allow termination ingress to reach the existing Save/Discard/Cancel coordinator: SwiftUI's `presentationPreventsAppTermination(false)` is used on macOS 15.4+ when compiled with Swift 6.1+, with a scoped and restoring `NSWindow.preventsApplicationTerminationWhenModal` fallback on macOS 14–15.3 and earlier compiler versions. The Q7 coordinator still begins with AppKit's immediate cancel response and permits one guarded reentry only when model identity, session revision, and the empty session registry still match. Apple documents the [SwiftUI presentation control](https://developer.apple.com/documentation/swiftui/view/presentationpreventsapptermination(_:)) and the [AppKit modal-window property](https://developer.apple.com/documentation/appkit/nswindow/preventsapplicationterminationwhenmodal). These are source-level changes, not native UI acceptance.

A native slice on the exact Q7/v4 Pip package exercised editing and reopening an existing synthetic note and observed Done, Cancel, and Save; the saved note remained after restart. Clean main-window Quit exited normally. Dirty Cmd-Q and enabled app-menu Quit produced no alert, and immediate PID checks confirmed the same process remained alive. This proves the missing dirty-quit prompt on that Q7 package; it does not establish Q8 behavior. The Q8 termination-ingress source has not been exercised natively.

The separate local-writer evidence remains unchanged: one synthetic Qwen3 1.7B probe produced valid JSON and citation IDs and identified a conflict, but misleadingly interpreted source/revision dates. In an opt-in production-model run, conflict-plus-persistence and hostile-source passed; the absent-fact case failed two expectations by repeating weekday hours without acknowledging that public-holiday information was missing. It did not explicitly invent a holiday time. The writer remains experimental and off by default; general grounding is not established.

The public `research-alpha-2026.10.23` releases remain historical. The intended `0.1.2` Core and `0.2.1` Plus updates have not been published. Earlier profile clone, CI, package, and native results do not qualify the current source or any future public payload.

## Still open

- Fresh hosted CI for the exact current public payload; local qualification 8 passed as recorded above.
- Packaged native Notes save/discard/cancel, pending-write, recovery, scene ownership, dirty close, Cmd-Q, menu quit, failure, and multi-editor behavior on the exact Q8 candidate. Q7/v4 reproduced the dirty-quit failure; Q8 remains unrun natively.
- Final independent review of the frozen export, licences/notices, profile inventories, packages, and release assets.
- Full NotebookLM/Gemini Notebook recreation, current reference geometry, VoiceOver, reduced-motion human review, macOS 14, Intel, and general local-writer grounding and persistence.

Local qualification 8 passes; Q7/v4 native dirty-quit failure is confirmed, and current Q8 native quit acceptance remains open. Source inspection, unit coverage, a build, signature, fixture, or static privacy scan cannot establish those outcomes.
