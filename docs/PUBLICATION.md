# Publication history

**Updated 25 October 2026.** The existing public repositories and 23 October experimental alpha releases are live and preserved. The intended Core `0.1.2` and Plus `0.2.1` updates remain unpublished; this update does not announce a new release:

- [`Ghostzy0/pip-research`](https://github.com/Ghostzy0/pip-research) contains Neutral Plus, Pip Core, and Pip Plus. Its published alpha release is [`research-alpha-2026.10.23`](https://github.com/Ghostzy0/pip-research/releases/tag/research-alpha-2026.10.23), with Core `0.1.1` and Plus `0.2.0` packages.
- [`Ghostzy0/pip-research-replica`](https://github.com/Ghostzy0/pip-research-replica) contains Neutral Core. Its published alpha release is [`research-alpha-2026.10.23`](https://github.com/Ghostzy0/pip-research-replica/releases/tag/research-alpha-2026.10.23), with a `0.1.1` package.

Those releases and assets are historical artifacts and have not been replaced. The next intended versions are Core `0.1.2` and Plus `0.2.1`. **No new package release is announced here.** Publication remains pending final export review, frozen-package/native checks, and the release process.

## Current qualification evidence

Qualification 8 completed 87 cases: 84 passed, 3 opt-in live-writer cases skipped, 0 failed. ResearchCore had 46 passes; ResearchDesktop had 41 cases, including the three skips (38 passed). All four source-declared products built and passed ad-hoc signature, resource, and private-path checks; source and resources were unchanged during the recorded run, 06:24:16–06:24:44 UTC. Test-log SHA-256: `d5f0029ddcac35284db741cf30e768b6a14fd4b988bdef52c3cd907032934827`. These are local source/package checks, not public-export privacy/licence acceptance, fresh-clone reproducibility, native UI acceptance, or release publication. Hosted 82-pass/3-skip checks qualify Q7 only. Fresh hosted CI against the Q8 public payload remains outstanding.

One bounded synthetic Qwen3 1.7B output returned valid JSON with the requested citation IDs and named the disagreement between two passages. It completed in 2.739 seconds but misleadingly interpreted source/revision dates as dates for the source values. Separately, the opt-in production-model run passed the conflict-plus-persistence case and the hostile-source case. The absent-fact case failed two expectations; asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging the source had weekday-hours information only. One synthetic persistence scenario passed, but general grounding and broader product persistence remain unverified. The writer remains experimental and disabled by default.

The Q8 Notes source preserves each scene's captured target and allows one editor owner per notebook. It lets termination ingress through the Notes sheet reach the existing Save/Discard/Cancel coordinator: SwiftUI's [`presentationPreventsAppTermination(false)`](https://developer.apple.com/documentation/swiftui/view/presentationpreventsapptermination(_:)) is used on macOS 15.4+ with Swift 6.1+, and a scoped, restoring [AppKit modal-window property](https://developer.apple.com/documentation/appkit/nswindow/preventsapplicationterminationwhenmodal) is used on macOS 14–15.3 and earlier compiler versions. These source changes do not establish native behavior.

On the exact Q7/v4 Pip package, editing and reopening an existing synthetic note and Done, Cancel, and Save worked; saved content persisted after restart, and clean main-window Quit exited normally. Dirty Cmd-Q and enabled menu Quit produced no alert, and immediate PID checks confirmed the same process remained alive. This confirms a dirty-quit failure on Q7/v4. The Q8 termination-ingress source has not been exercised natively, so its behavior remains unverified.

## Published release checks, 23 October

At the time of the historical alpha publication, the release notes recorded hosted CI, independent export/profile checks, and downloaded asset checksum verification. Those receipts apply to the 23 October source and packages only. They are not evidence for the resumed source, next intended versions, or any future release.

The current source and release boundaries are described in [verification](../TESTING.md), [parity](../PARITY.md), and the [edition matrix](EDITION-MATRIX.md). Package downloads are ad-hoc signed, not Developer ID signed or notarised. Verify an asset's published checksum and inspect the release notes before installing it.
