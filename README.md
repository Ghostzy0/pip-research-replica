# Research Notebook

An independent native macOS partial recreation of a focused NotebookLM / Gemini Notebook workflow: ask questions about local documents, inspect supporting passages, follow citations to sources, and export a notebook. It is not affiliated with or endorsed by Google, NotebookLM, Gemini, or Apple.

**Experimental partial workflow recreation.** This repository exports Neutral Core only:

| Build alias | Swift product | Edition | Intended source version |
|---|---|---|---:|
| baseline | ResearchBaseline | Research Baseline | 0.1.2 |

The next intended version is not yet published. The 23 October alpha remains the existing historical release; see [publication history](docs/PUBLICATION.md).

The source implements notebook-scoped manual notes and interrupted-edit recovery. Each scene retains its captured notebook target, with one Notes editor owner per notebook. Normal termination begins with AppKit's immediate cancel response while the asynchronous Save/Discard/Cancel coordinator runs on the normal run loop. One guarded termination reentry is permitted only if model identity, session revision, and the empty session registry still match. This source behavior is not native UI acceptance.

## What it does

- Create local notebooks and import copied PDF, UTF-8 TXT, and Markdown sources.
- Select evidence sources for a question and retain chats after restart.
- Inspect quoted passages, source pages/headings, and open cited locations.
- Compare conflicting statements, see when retrieval found no support, and export notebook evidence as Markdown.
- Write manual notebook notes, separate from imported sources and generated drafts.

Evidence responses are not guaranteed facts. The app does not reproduce the complete NotebookLM/Gemini Notebook product or visual identity.

## Build

Requires macOS 14+ and Swift 6+. Evidence workflows need no third-party packages, accounts, server, or model weights.

~~~sh
swift test --jobs 2
./scripts/build.sh baseline
open 'dist/Research Baseline.app'
~~~

The app is ad-hoc signed, not Developer ID signed or notarised. Do not disable macOS security globally. See [AI setup](docs/AI-SETUP.md), [testing](TESTING.md), and [parity](PARITY.md).

## Qualification status

Qualification 7 completed 85 cases: 82 passed, 3 opt-in live-writer cases skipped, 0 failed. All four products built and passed ad-hoc signature and private-path checks. These are local source/package checks, not native UI acceptance. Hosted 77-pass/3-skip checks qualify the earlier AppKit bridge only; fresh hosted CI for the current public payload remains outstanding. Neutral Core does not generate answers; the shared optional-writer fixtures do not activate generation in this edition.

Neutral Core does not implement full generative answers, Studio/audio/video artifacts, web/video/cloud imports, OCR, sharing, or complete reference behavior. Broader accessibility, macOS 14, and Intel acceptance remain open. See [testing](TESTING.md), [parity](PARITY.md), and [publication history](docs/PUBLICATION.md).
