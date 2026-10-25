# Research Notebook

An independent native macOS partial recreation of a focused NotebookLM / Gemini Notebook workflow: ask questions about local documents, inspect supporting passages, follow citations to sources, and export a notebook. It is not affiliated with or endorsed by Google, NotebookLM, Gemini, or Apple.

**Experimental partial workflow recreation.** This repository exports Neutral Core only:

| Build alias | Swift product | Edition | Intended source version |
|---|---|---|---:|
| baseline | ResearchBaseline | Research Baseline | 0.1.2 |

The current source version is Neutral Core `0.1.2`. Check [the Neutral Core release page](https://github.com/Ghostzy0/pip-research-replica/releases/tag/research-alpha-2026.10.25) for current publication status, assets, and checksums. The 23 October alpha remains the historical release; see [publication history](docs/PUBLICATION.md).

Q9 source gates termination before `super.terminate` can tear down Notes sheets; an early principal-class subclass provides a typed bridge, and guarded one-shot approval covers the native delegate query; direct system queries use `terminateLater` and one reply. Unavailable active Notes sessions and dirty `.close` requests fail closed; pre-model startup can terminate before any Notes session exists. Thirteen Q9 source regressions cover these paths. Q10 passed 96 local cases (93 passed, 3 skipped, 0 failed), and both exact public heads passed hosted CI with the same result. The final v7 Neutral Plus native slice passed fact-bearing retrieval, excerpt/export/restart, dirty Cmd-Q Cancel, and explicit editor Save followed by clean Quit/relaunch on macOS 27.0.1. Baseline, Pip Core, and Pip Plus passed final v7 startup/saved-note/clean-quit smoke. The scoped experimental patch is accepted for publication; check the Neutral Core release page above for current asset availability and checksums.

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

Qualification 10 completed 96 cases: 93 passed, 3 opt-in live-writer cases skipped, 0 failed; all four products passed local build/package checks. Both exact Q10 public heads passed hosted CI with the same result on Swift 6.1.2/macOS 15.7.9 arm64. All four Q9 prior-package variants passed startup and dirty Cmd-Q Cancel/alert-Save/restart; Pip Core also passed menu Discard/restart. Q9 Neutral Plus fact-bearing retrieval failed and remains in [public issue #6](https://github.com/ghostzy0/pip-research/issues/6). On v7 Neutral Plus, citations included 18:00 and 19:00, conflict detection passed, and the saved 19:00 excerpt/export survived restart. Dirty Cmd-Q Cancel retained the same PID/edit; the save used the editor Save button, followed by clean Quit and relaunch. Baseline, Pip Core, and Pip Plus passed final v7 startup/saved-note/clean-quit smoke. The scoped experimental patch is accepted for publication; check the Neutral Core release page for current package status. Neutral Core does not generate answers; the shared optional-writer fixtures do not activate generation in this edition.

Neutral Core does not implement full generative answers, Studio/audio/video artifacts, web/video/cloud imports, OCR, sharing, or complete reference behavior. Broader accessibility, macOS 14, and Intel acceptance remain open. See [testing](TESTING.md), [parity](PARITY.md), and [publication history](docs/PUBLICATION.md).
