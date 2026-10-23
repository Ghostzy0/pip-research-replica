# Public repository profiles

Source is published in two repositories with fresh app-specific histories. Names identify distribution profiles; they do not imply complete reference parity.

| Repository | Runnable products | Owner aliases |
| --- | --- | --- |
| [pip-research](https://github.com/Ghostzy0/pip-research) | ResearchBaselineEnhanced, PipResearch, PipResearchEnhanced | Neutral Plus, Pip Core, Pip Plus |
| [pip-research-replica](https://github.com/Ghostzy0/pip-research-replica) | ResearchBaseline | Neutral Core |

Both carry the same original ResearchCore and ResearchDesktop sources and shared regression tests. Each exports only its owned executable entry points. Shared core hashes, reviewed public commits, passing hosted CI and exact package identities are recorded in [publication verification](PUBLICATION.md). Build aliases, bundle identifiers, versions and separate storage folders are in [the edition matrix](EDITION-MATRIX.md).

Each profile passed 67 tests with one intentional live-model skip and all owned release builds on hosted macOS 15 / Swift 6.1. Local packages also passed signatures, metadata, resources and privacy checks. Binary download availability and exact-package native smoke are stated in actual release notes. All distributed packages are experimental, locally ad-hoc signed and not notarized.

The implementation remains a partial workflow recreation. Full native reference parity, generated Studio features, accessibility/device coverage and accepted local generation remain incomplete. The optional writer failed citation and source-agreement checks and stays off by default. A bounded synthetic note-recovery flow passed; dirty-modal Cmd-Q and same-notebook multiwindow recovery need further work. See [testing](../TESTING.md) and [parity](../PARITY.md).
