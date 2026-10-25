# Review and qualification record

**Updated 25 October 2026.** Qualification 9 completed 91 cases: 88 passed, 3 opt-in live-writer cases skipped, 0 failed. All four products passed local build/package checks, including principal-class, ad-hoc signature, resource, private-path, and mode checks. These results cover source and local packages only. Hosted 82-pass/3-skip CI qualifies Q7 only; hosted CI for the current Q9 public payload remains pending. Neither source tests nor package checks establish native acceptance.

The Q8 source policy kept each Notes scene bound to its captured notebook and allowed one editor owner per notebook. It used SwiftUI's [`presentationPreventsAppTermination(false)`](https://developer.apple.com/documentation/swiftui/view/presentationpreventsapptermination(_:)) on macOS 15.4+ with Swift 6.1+, and a scoped, restoring `NSWindow.preventsApplicationTerminationWhenModal` fallback on macOS 14–15.3 and earlier compiler versions. Apple documents the [SwiftUI presentation control](https://developer.apple.com/documentation/swiftui/view/presentationpreventsapptermination(_:)) and the [AppKit modal-window property](https://developer.apple.com/documentation/appkit/nswindow/preventsapplicationterminationwhenmodal). This is historical Q8 source behavior; it did not pass the later native quit gate.

The current Q9 source gates native termination ingress before `super.terminate` can tear down Notes sheets. A principal-class subclass installs early at startup and provides a typed bridge. A guarded one-shot approval covers the native delegate query; direct system queries use `terminateLater` and one reply. Unavailable active Notes sessions and dirty `.close` requests fail closed; pre-model startup can terminate before any Notes session exists. Thirteen source regression tests cover delegate and ingress paths. These are source-level facts only: Q9's packaged runtime class and quit/recovery behavior remain unverified.

A native slice on the exact Q7/v4 Pip package exercised editing and reopening an existing synthetic note and observed Done, Cancel, and Save; the saved note remained after restart. Clean main-window Quit exited normally. Dirty Cmd-Q and enabled app-menu Quit produced no alert, and immediate PID checks confirmed the same process remained alive. In a later bounded Q8 native slice, dirty Cmd-Q and menu Quit both exited without a prompt. Reopening offered recovery; restoring it recovered the edited synthetic draft while the saved library remained unchanged. The Q8 native dirty-quit gate failed because neither route offered Save/Discard/Cancel. Q9 has not been run natively.

The separate local-writer evidence remains unchanged: one synthetic Qwen3 1.7B probe produced valid JSON and citation IDs and identified a conflict, but misleadingly interpreted source/revision dates. In an opt-in production-model run, conflict-plus-persistence and hostile-source passed; the absent-fact case failed two expectations by repeating weekday hours without acknowledging that public-holiday information was missing. It did not explicitly invent a holiday time. The writer remains experimental and off by default; general grounding is not established.

The public `research-alpha-2026.10.23` releases remain historical. The intended `0.1.2` Core and `0.2.1` Plus updates have not been published. Earlier profile clone, CI, package, and native results do not qualify the current source or any future public payload.

## Still open

- Hosted CI for the exact current Q9 public payload; Q9 local qualification passed as recorded above.
- Packaged native Q9 runtime class/typed-bridge confirmation and Notes save/discard/cancel, recovery, dirty close, Cmd-Q, menu quit, failure, and multi-editor behavior. Q8's exact native slice failed to show a quit prompt; Q9 remains unrun natively.
- Final independent review of the frozen export, licences/notices, profile inventories, packages, and release assets.
- Full NotebookLM/Gemini Notebook recreation, current reference geometry, VoiceOver, reduced-motion human review, macOS 14, Intel, and general local-writer grounding and persistence.

Q9 local qualification passes; Q8's native dirty-quit failure is confirmed, and Q9 native quit acceptance and hosted CI remain open. Source inspection, unit coverage, a build, signature, fixture, or static privacy scan cannot establish those outcomes.
