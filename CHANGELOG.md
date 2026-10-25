# Changelog

## Unreleased — intended next version: Neutral Core 0.1.2

This version number identifies the next source/package batch; this entry does not announce a published release. The existing 23 October experimental alpha remains available and unchanged. See [publication history](docs/PUBLICATION.md).

- Neutral Core provides local notebooks, copied PDF/TXT/Markdown sources, source selection, evidence chats, citation navigation, manual notes, and Markdown export. It is an experimental partial workflow recreation, not accepted full NotebookLM/Gemini Notebook fidelity.
- Hardened manual Notes ownership and interrupted-edit recovery across scenes. Q8 lets termination ingress through the Notes sheet reach the existing Save/Discard/Cancel coordinator, using SwiftUI's `presentationPreventsAppTermination(false)` on macOS 15.4+ with Swift 6.1+ and a scoped, restoring AppKit fallback on macOS 14–15.3 and earlier compiler versions. This source change is not native acceptance.
- Qualification 8 completed 87 cases: 84 passed, 3 opt-in live-writer cases skipped, 0 failed. All four products built and passed ad-hoc signature, resource, and private-path checks. Hosted 82-pass/3-skip checks qualify Q7 only; fresh Q8 public-payload CI and Q8 native review remain pending. Exact Q7/v4 native evidence confirmed that dirty Cmd-Q and menu Quit showed no alert while the same PID remained alive; note save/reopen, restart persistence, and clean main-window Quit passed.
- Optional local Qwen3 1.7B drafting stays off by default and experimental. One bounded synthetic response included citation IDs and named the conflict, but gave a misleading interpretation of source dates. Separately, an opt-in live run passed conflict-plus-persistence and hostile-source cases; absent-fact failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that the source only gives weekday hours. It did not explicitly invent holiday hours. One persistence scenario passed; general grounding remains unverified.

## 23 October 2026 — historical experimental alpha

The previous Neutral Core alpha was published from `pip-research-replica` as version `0.1.1`. The public release remains unchanged; its own source, package, and qualification evidence remain historical. See [publication history](docs/PUBLICATION.md).
