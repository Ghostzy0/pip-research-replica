# Changelog

## Unreleased — intended next version: Neutral Core 0.1.2

This version number identifies the next source/package batch; this entry does not announce a published release. The existing 23 October experimental alpha remains available and unchanged. See [publication history](docs/PUBLICATION.md).

- Neutral Core provides local notebooks, copied PDF/TXT/Markdown sources, source selection, evidence chats, citation navigation, manual notes, and Markdown export. It is an experimental partial workflow recreation, not accepted full NotebookLM/Gemini Notebook fidelity.
- Manual notes now use one editor owner per notebook across scenes and retain the scene's captured notebook target. A shared AppKit termination delegate routes normal termination through the deferred Save/Discard/Cancel coordinator; four bridge tests cover its exactly-once reply. Packaged native Dock/menu/Cmd-Q/window-close acceptance remains pending.
- Qualification-4 default Swift suite: 80 cases: 77 passed, 3 opt-in live-writer cases skipped, 0 failures. All four products were built, ad-hoc signature-verified, and checked for private-path strings. Separately, an opt-in run passed conflict-plus-persistence and hostile-source cases; absent-fact failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that the source only gives weekday hours. It did not explicitly invent holiday hours.
- Optional local Qwen3 1.7B drafting stays off by default and experimental. One bounded synthetic response included citation IDs and named the conflict, but gave a misleading interpretation of source dates. Separately, an opt-in live run passed conflict-plus-persistence and hostile-source cases; absent-fact failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that the source only gives weekday hours. It did not explicitly invent holiday hours. One persistence scenario passed; general grounding remains unverified.

## 23 October 2026 — historical experimental alpha

The previous Neutral Core alpha was published from `pip-research-replica` as version `0.1.1`. The public release remains unchanged; its own source, package, and qualification evidence remain historical. See [publication history](docs/PUBLICATION.md).
