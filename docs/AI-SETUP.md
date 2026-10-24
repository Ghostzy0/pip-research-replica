# AI-assisted setup

Use this prompt with an assistant that has local filesystem and terminal access:

> Set up this checked-out Research Notebook repository on my Mac. Read README and SECURITY first. Check macOS and Swift, run the default tests, build the single product listed by this profile, and show its app path. Preserve existing notebooks and OS security settings. Do not install accounts, paid services, providers, or model weights.

## Commands

Requires macOS 14+ and Swift 6 from Xcode or Apple's Command Line Tools.

~~~sh
swift --version
swift test --jobs 2
./scripts/build.sh baseline
open 'dist/Research Baseline.app'
~~~

This repository exports Neutral Core only, a partial independent recreation of a local-source question, evidence, and citation-navigation workflow. Do not build or describe unowned Pip editions from this repository.

The 24 October qualification-3 source suite completed 76 cases: 73 passed, 3 opt-in live-writer cases skipped, 0 failures. All four declared products were built, signature-verified, and checked for private-path strings. These checks do not establish native UI behavior, full reference parity, or release of the intended new version. Separately, an opt-in run passed conflict-plus-persistence and hostile-source cases; absent-fact failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that the source only gives weekday hours. It did not explicitly invent holiday hours.

The optional local Qwen writer is off by default and experimental. One bounded synthetic Qwen3 1.7B output returned valid JSON with citation IDs and named a source disagreement, but also misleadingly interpreted source dates. Do not promise general grounding or accepted generated drafts. The app does not install models or use cloud fallback.

Use the synthetic sample or import local PDF, UTF-8 TXT, and Markdown sources. Sources are copied to app-owned local storage. Notes are local and included in Markdown export; unfinished edits may be recovered from an app-owned sidecar. The Notes editor is bound to the notebook captured by its scene, with one owner per notebook across scenes. App quit requests Save, Discard, or Cancel and waits for writes/recovery. Packaged native acceptance remains pending.

See [testing](../TESTING.md), [parity](../PARITY.md), and [publication history](PUBLICATION.md). Local apps are ad-hoc signed, not Developer ID signed or notarised.
