# Publication history

**Updated 24 October 2026.** The existing public repositories and 23 October experimental alpha releases are live and preserved:

- [`Ghostzy0/pip-research`](https://github.com/Ghostzy0/pip-research) contains Neutral Plus, Pip Core, and Pip Plus. Its published alpha release is [`research-alpha-2026.10.23`](https://github.com/Ghostzy0/pip-research/releases/tag/research-alpha-2026.10.23), with Core `0.1.1` and Plus `0.2.0` packages.
- [`Ghostzy0/pip-research-replica`](https://github.com/Ghostzy0/pip-research-replica) contains Neutral Core. Its published alpha release is [`research-alpha-2026.10.23`](https://github.com/Ghostzy0/pip-research-replica/releases/tag/research-alpha-2026.10.23), with a `0.1.1` package.

Those releases and assets are historical artifacts and have not been replaced. The next intended versions are Core `0.1.2` and Plus `0.2.1`. **No 24 October source update or package release is announced here.** Publication remains pending final export review, frozen-package/native checks, and the release process.

## Current qualification evidence

The 24 October qualification-4 source suite completed 80 cases: 77 passed, 3 opt-in live-writer cases skipped, 0 failures. All four source-declared products were built, ad-hoc signature-verified, and scanned for private-path strings. These are local source/package checks; they do not establish public-export privacy/licence acceptance, fresh-clone reproducibility of the resumed export, native Notes interaction, or release publication.

One bounded synthetic Qwen3 1.7B output returned valid JSON with the requested citation IDs and named the disagreement between two passages. It completed in 2.739 seconds but misleadingly interpreted source/revision dates as dates for the source values. Separately, the opt-in production-model run passed the conflict-plus-persistence case and the hostile-source case. The absent-fact case failed two expectations; asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging the source had weekday-hours information only. One synthetic persistence scenario passed, but general grounding and broader product persistence remain unverified. The writer remains experimental and disabled by default.

The Notes source preserves each scene's captured target and enforces one editor owner per notebook. A shared AppKit termination delegate routes normal termination through the deferred Save/Discard/Cancel coordinator; four source tests cover its exactly-once reply behavior. Native Dock/menu/Cmd-Q/window-close and multiwindow flows remain unaccepted.

## Published release checks, 23 October

At the time of the historical alpha publication, the release notes recorded hosted CI, independent export/profile checks, and downloaded asset checksum verification. Those receipts apply to the 23 October source and packages only. They are not evidence for the resumed source, next intended versions, or any future release.

The current source and release boundaries are described in [verification](../TESTING.md), [parity](../PARITY.md), and the [edition matrix](EDITION-MATRIX.md). Package downloads are ad-hoc signed, not Developer ID signed or notarised. Verify an asset's published checksum and inspect the release notes before installing it.
