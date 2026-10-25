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

Neutral Core provides extractive source passages and citations; it does not generate answers. Shared optional-writer fixtures in the source suite do not activate generation in this edition.

Run the default suite and this profile's build command to check your checkout. Read [testing](../TESTING.md) for dated source, package and native results; a successful build does not establish native behavior or full reference parity.

Use the synthetic sample or import local PDF, UTF-8 TXT, and Markdown sources. Sources are copied to app-owned local storage. Notes are local and included in Markdown export; unfinished edits may be recovered from an app-owned sidecar. The Notes editor is bound to the notebook captured by its scene, with one owner per notebook across scenes. Use Done to choose Save, Discard, or Cancel for unfinished edits. Check the dated testing record for the exact build's tested quit and recovery behavior.

See [testing](../TESTING.md), [parity](../PARITY.md), and [publication history](PUBLICATION.md). Local apps are ad-hoc signed, not Developer ID signed or notarised.
