# AI-assisted setup

Use this prompt with an assistant that has local filesystem and terminal access:

> Set up this checked-out Research Notebook repository on my Mac. Read README and SECURITY first. Check macOS and Swift, run the default tests, build the single product listed by this repository profile, and show its app path. Preserve existing notebooks and OS security settings. Do not install accounts, paid services, providers or model weights.

## Commands

Requires macOS 14+ and Swift 6+ from Xcode or Apple's Command Line Tools.

~~~sh
swift --version
swift test --jobs 2
./scripts/build.sh baseline
open 'dist/Research Baseline.app'
~~~

This repository exports one runnable app, Research Baseline. It is a partial independent recreation of a local-source question, evidence and citation-navigation workflow. Do not build or describe unowned Pip editions from this repository.

The optional local Qwen draft path is disabled by default and unaccepted. After the request grammar and schema were corrected, the tested model returned valid JSON but omitted citations and made an unsupported agreement claim; the app rejected it and saved no draft. Evidence retrieval and citation navigation are separate. Do not promise working generated drafts.

The shared default suite completed 68 cases: 67 passed, one opt-in live test was skipped, and none failed. The v3 profile clean-clone test/build/signature checks passed: three custom products and one replica product across both profiles. The live test remains skipped because the tested local writer returned valid JSON without citations and with an unsupported claim that conflicting sources agreed; validation rejected it and saved no draft. Generation remains off by default. Packaging strips local debug metadata from the copied app executable before ad-hoc signing.

Use the synthetic sample or import local PDF, UTF-8 TXT or Markdown sources. The app copies selected originals into its own Application Support folder. Removing an imported source does not alter the external original. Back up the full data folder with the app closed.

Confirm the single listed app launches, use the sample, open citations and export a notebook. A passing source test or build is not full reference parity, native accessibility or VoiceOver acceptance.
