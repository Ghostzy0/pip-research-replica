# Review and qualification record

**Updated 24 October 2026.** The qualification-3 default suite completed 76 cases: 73 passed, 3 opt-in live-writer cases skipped, 0 failures. All four release products were built, ad-hoc signature-verified, and checked for private-path strings. Separately, an opt-in live run passed the conflict-plus-persistence and hostile-source cases; the absent-fact case failed two expectations. Static path scans are a narrow check; they do not establish that every document, screenshot, notice, or source file is publishable.

The updated Notes implementation now owns one editor per notebook across scenes, retains the scene's captured notebook target, and coordinates explicit Save, Discard, or Cancel choices when the app quits. Source tests cover ownership and the quit coordinator's ordering, stale requests, cancellation, and commit failure cases. Packaged native Notes/quit acceptance for this resumed implementation remains pending. Earlier Cmd-Q behavior in a dirty Notes sheet had no visible response; current packages must demonstrate the fix before acceptance.

One bounded local synthetic probe of the pinned Qwen3 1.7B returned valid JSON with the required citation IDs and named a two-source disagreement in 2.739 seconds. It also made a misleading interpretation of source/revision dates as dates for the values. Separately, the opt-in production-model run passed the conflict-plus-persistence case and the hostile-source case. The absent-fact case failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` It did not explicitly invent holiday hours, but failed to acknowledge that the source gives weekday hours only and no public-holiday information. One synthetic persistence scenario passed, but this does not establish general grounding or broad product persistence. The writer remains experimental and off by default. A bounded raw Qwen3.5 0.8B comparison repeated the missing-support failure and was not adopted; no further model comparisons are part of this release review.

Historical evidence remains versioned to the build examined. The public `research-alpha-2026.10.23` releases remain available as published; the `0.1.2` Core and `0.2.1` Plus source/package updates are not yet published. Earlier profile clone, CI, package, and native results do not automatically qualify the resumed source or current exports.

## Still open

- Packaged Notes create/edit/save/reopen, recovery, scene ownership, dirty close, Cmd-Q, failure and multi-editor behavior.
- Independent review of the exact frozen public export inventories, prose, images, fixtures, licences, notices and package contents.
- Fresh clean clones and builds of each new public profile export, then downloaded release asset hash and extraction checks.
- Full NotebookLM/Gemini Notebook recreation, current reference geometry, VoiceOver, reduced-motion human review, macOS 14, Intel, and general local-writer grounding and persistence.

The qualification results support an experimental source/package milestone only. They are not a completed independent final gate, native acceptance, accepted generation, full parity, or stable-production claim.
