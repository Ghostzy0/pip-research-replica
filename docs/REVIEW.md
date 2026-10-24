# Review and qualification record

**Updated 24 October 2026.** Qualification 7 completed 85 cases: 82 passed, 3 opt-in live-writer cases skipped, 0 failed. ResearchCore had 46 passes; ResearchDesktop had 39 cases, including the three skips (36 passed). All four products built, passed ad-hoc signature verification, and passed private-path checks; source and resources were unchanged during the recorded run, 19:12:55–19:13:17 UTC. The hosted 77-pass/3-skip result qualifies the earlier AppKit bridge only. Fresh hosted CI against the current public payload remains outstanding.

The current source keeps each Notes scene bound to its captured notebook, allows one editor owner per notebook, and retains interrupted-edit recovery. Normal termination begins with AppKit's immediate cancel response while the asynchronous Save/Discard/Cancel coordinator runs on the normal run loop. It permits one guarded termination reentry only when model identity, session revision, and the empty session registry still match. This implementation does not use a `terminateLater`/reply guarantee. Source behavior is not native UI acceptance.

A narrow native slice on the previous qualification-4 packaged candidate exercised synthetic Notes create/save/edit/reopen and observed Done, Cancel, and Save. Dirty Cmd-Q and an enabled menu Quit produced no prompt. The process ID was not checked then, so whether the app had quit is unresolved; the cause is unproven. This slice does not establish quit acceptance. The current termination-coordination source has not been exercised natively.

The separate local-writer evidence remains unchanged: one synthetic Qwen3 1.7B probe produced valid JSON and citation IDs and identified a conflict, but misleadingly interpreted source/revision dates. In an opt-in production-model run, conflict-plus-persistence and hostile-source passed; the absent-fact case failed two expectations by repeating weekday hours without acknowledging that public-holiday information was missing. It did not explicitly invent a holiday time. The writer remains experimental and off by default; general grounding is not established.

The public `research-alpha-2026.10.23` releases remain historical. The intended `0.1.2` Core and `0.2.1` Plus updates have not been published. Earlier profile clone, CI, package, and native results do not qualify the current source or any future public payload.

## Still open

- Fresh hosted CI for the exact current public payload; local qualification 7 passed as recorded above.
- Packaged native Notes save/discard/cancel, pending-write, recovery, scene ownership, dirty close, Cmd-Q, menu quit, failure, and multi-editor behavior on the exact current candidate.
- Final independent review of the frozen export, licences/notices, profile inventories, packages, and release assets.
- Full NotebookLM/Gemini Notebook recreation, current reference geometry, VoiceOver, reduced-motion human review, macOS 14, Intel, and general local-writer grounding and persistence.

Local qualification 7 passes; current native quit acceptance remains open. Source inspection, unit coverage, a build, signature, fixture, or static privacy scan cannot establish those outcomes.
