# Research Notebook

An independent native macOS partial recreation of a focused NotebookLM / Gemini Notebook workflow: ask questions about local documents, inspect supporting passages, follow citations to sources, and export a notebook. It is not affiliated with or endorsed by Google, NotebookLM, Gemini, or Apple.

**Experimental partial workflow recreation.** This repository exports Neutral Core only:

| Build alias | Swift product | Edition | Intended source version |
|---|---|---|---:|
| baseline | ResearchBaseline | Research Baseline | 0.1.2 |

The next intended version is not yet published. The 23 October alpha remains the existing historical release; see [publication history](docs/PUBLICATION.md).

The source implements notebook-scoped manual notes and interrupted-edit recovery. Each scene retains its captured notebook target, with one Notes editor owner per notebook. A shared AppKit termination delegate routes normal termination through the deferred Save/Discard/Cancel coordinator; four bridge tests cover its exactly-once reply. Packaged native Dock/menu/Cmd-Q/window-close behavior remains unaccepted.

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

The 24 October qualification-4 default suite completed 80 cases: 77 passed, 3 opt-in live-writer cases skipped, 0 failures. All four source-declared products built, passed ad-hoc signature verification, and passed private-path string scans. Separately, an opt-in live run passed the conflict-plus-persistence and hostile-source cases; absent-fact failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that the source only gives weekday hours. It did not explicitly invent holiday hours. This is not general grounding evidence. These checks do not establish native Notes acceptance or full reference parity. Local generation remains off by default and experimental.

Neutral Core does not implement full generative answers, Studio/audio/video artifacts, web/video/cloud imports, OCR, sharing, or complete reference behavior. Broader accessibility, macOS 14, and Intel acceptance remain open. See [testing](TESTING.md), [parity](PARITY.md), and [publication history](docs/PUBLICATION.md).
