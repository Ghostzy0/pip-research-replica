# Two public repositories

**Updated 24 October 2026.** The existing public repositories and their history are preserved. Their first experimental alpha releases are historical 23 October artifacts; the resumed source changes are being prepared for a later reviewed release. No 24 October release is claimed here.

| Public repository | Editions | Intended source versions | Current boundary |
|---|---|---|---|
| [`pip-research`](https://github.com/Ghostzy0/pip-research) | Neutral Plus, Pip Core, Pip Plus | `0.2.1`, `0.1.2`, `0.2.1` | Shared original implementation; next export/package batch still requires final review and release |
| [`pip-research-replica`](https://github.com/Ghostzy0/pip-research-replica) | Neutral Core | `0.1.2` | Partial workflow recreation; full reference fidelity is not accepted |

Existing historical release links: [custom editions, 23 October](https://github.com/Ghostzy0/pip-research/releases/tag/research-alpha-2026.10.23) and [Neutral Core, 23 October](https://github.com/Ghostzy0/pip-research-replica/releases/tag/research-alpha-2026.10.23). Those assets and source snapshots are not replaced by the intended versions above.

## Shared source and variant identity

Both public repositories contain the shared core and tests. The custom repository owns three executable entry points; the replica repository owns only Neutral Core. Each public repository has its own build profile and manifest. The common implementation does not make the four editions identical: Core omits Plus search/saved-excerpt controls, while Plus editions contain the same additions in neutral or Pip presentation.

The per-notebook Notes owner is bound to the notebook captured by its scene. A shared AppKit termination delegate routes normal termination through the deferred Save/Discard/Cancel coordinator; four source tests cover its exactly-once reply behavior. Native Dock, menu, Cmd-Q, window-close, and multiwindow behavior is not yet accepted.

## Evidence and limits

The 24 October qualification-4 default suite completed 80 cases: 77 passed, 3 opt-in live-writer cases skipped, 0 failures. All four release products were built, signature-verified, and scanned for private-path strings. Separately, an opt-in run passed conflict-plus-persistence and hostile-source cases; absent-fact failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that the source only gives weekday hours. It did not explicitly invent holiday hours. This does not establish native UI acceptance, accessibility, a clean-clone review of the next export, or public release of the new versions.

One bounded synthetic Qwen3 1.7B response took 2.739 seconds and included the required citation IDs and stated that the two source values conflict. It also misleadingly interpreted source/revision dates as dates for the values. Separately, the opt-in production-model run passed the conflict-plus-persistence and hostile-source cases. The absent-fact case failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` It did not explicitly invent holiday hours, but failed to acknowledge that the source gives weekday hours only and no public-holiday information. One synthetic persistence scenario passed, but general grounding and broader persistence remain unverified. The writer remains experimental and off by default.

NotebookLM/Gemini Notebook parity, generated Studio/audio workflows, OCR and web/video/cloud imports remain incomplete. See [parity](../PARITY.md), [testing](../TESTING.md), [the edition matrix](EDITION-MATRIX.md), and the updated [publication record](PUBLICATION.md).
