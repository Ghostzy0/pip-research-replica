# Publication history

**Updated 24 October 2026.** The existing public repositories and 23 October experimental alpha releases are live and preserved:

- [`Ghostzy0/pip-research`](https://github.com/Ghostzy0/pip-research) contains Neutral Plus, Pip Core, and Pip Plus. Its published alpha release is [`research-alpha-2026.10.23`](https://github.com/Ghostzy0/pip-research/releases/tag/research-alpha-2026.10.23), with Core `0.1.1` and Plus `0.2.0` packages.
- [`Ghostzy0/pip-research-replica`](https://github.com/Ghostzy0/pip-research-replica) contains Neutral Core. Its published alpha release is [`research-alpha-2026.10.23`](https://github.com/Ghostzy0/pip-research-replica/releases/tag/research-alpha-2026.10.23), with a `0.1.1` package.

Those releases and assets are historical artifacts and have not been replaced. The next intended versions are Core `0.1.2` and Plus `0.2.1`. **No 24 October package release is announced here.** Publication remains pending final export review, frozen-package/native checks, and the release process.

## Current qualification evidence

Qualification 7 completed 85 cases: 82 passed, 3 opt-in live-writer cases skipped, 0 failed. All four source-declared products built, passed ad-hoc signature verification, and passed private-path checks; source and resources were unchanged during the recorded run, 19:12:55–19:13:17 UTC. These are local source/package checks, not public-export privacy/licence acceptance, fresh-clone reproducibility, native UI acceptance, or release publication. Hosted 77-pass/3-skip checks apply to the earlier AppKit bridge only. Fresh hosted CI against the current public payload remains outstanding.

One bounded synthetic Qwen3 1.7B output returned valid JSON with the requested citation IDs and named the disagreement between two passages. It completed in 2.739 seconds but misleadingly interpreted source/revision dates as dates for the source values. Separately, the opt-in production-model run passed the conflict-plus-persistence case and the hostile-source case. The absent-fact case failed two expectations; asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging the source had weekday-hours information only. One synthetic persistence scenario passed, but general grounding and broader product persistence remain unverified. The writer remains experimental and disabled by default.

The current Notes source preserves each scene's captured target and allows one editor owner per notebook. Normal termination uses AppKit's immediate cancel response while the asynchronous Save/Discard/Cancel coordinator runs on the normal run loop. It permits one guarded termination reentry only when model identity, session revision, and the empty session registry still match; it does not use a `terminateLater`/reply guarantee. A narrow native slice on the previous qualification-4 candidate exercised synthetic Notes create/save/edit/reopen and observed Done, Cancel, and Save. Dirty Cmd-Q and an enabled menu Quit produced no prompt; the process ID was not checked then, so whether the app had quit is unresolved and the cause is unproven. The current termination-coordination source has not been run natively, and no quit acceptance is claimed.

## Published release checks, 23 October

At the time of the historical alpha publication, the release notes recorded hosted CI, independent export/profile checks, and downloaded asset checksum verification. Those receipts apply to the 23 October source and packages only. They are not evidence for the resumed source, next intended versions, or any future release.

The current source and release boundaries are described in [verification](../TESTING.md), [parity](../PARITY.md), and the [edition matrix](EDITION-MATRIX.md). Package downloads are ad-hoc signed, not Developer ID signed or notarised. Verify an asset's published checksum and inspect the release notes before installing it.
