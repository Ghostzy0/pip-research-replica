# Research Notebook

An independent native macOS partial recreation of a focused NotebookLM / Gemini Notebook workflow: ask questions about local documents, inspect supporting passages, follow citations to sources, and export a notebook. It is not affiliated with or endorsed by Google, NotebookLM, Gemini, or Apple.

**Experimental partial workflow recreation.** This repository exports Neutral Core only:

| Build alias | Swift product | Edition | Intended source version |
|---|---|---|---:|
| baseline | ResearchBaseline | Research Baseline | 0.1.2 |

The next intended version is not yet published. The 23 October alpha remains the existing historical release; see [publication history](docs/PUBLICATION.md).

The source implements notebook-scoped manual notes and interrupted-edit recovery. Each scene retains its captured notebook target, with one Notes editor owner per notebook. The retained Q8 sheet policy lets termination ingress through the Notes sheet reach the Save/Discard/Cancel coordinator, using SwiftUI's [`presentationPreventsAppTermination(false)`](https://developer.apple.com/documentation/swiftui/view/presentationpreventsapptermination(_:)) on macOS 15.4+ with Swift 6.1+, and a scoped, restoring [AppKit modal-window setting](https://developer.apple.com/documentation/appkit/nswindow/preventsapplicationterminationwhenmodal) on macOS 14–15.3 and earlier compiler versions. Current Q9 source gates termination before `super.terminate` can tear down Notes sheets; an early principal-class subclass provides a typed bridge, and a guarded one-shot approval covers the native delegate query; direct system queries use `terminateLater` and one reply. Unavailable active Notes sessions and dirty `.close` requests fail closed; pre-model startup can terminate before any Notes session exists. Thirteen source regression tests cover these paths, but do not establish packaged behavior.

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

Qualification 9 completed 91 cases: 88 passed, 3 opt-in live-writer cases skipped, 0 failed. All four products passed local build/package checks; these are not native UI acceptance. On the exact Q7/v4 Pip package, dirty Cmd-Q and menu Quit showed no alert while the same PID remained alive. A later Q8 native slice found both routes exited without a prompt; reopening recovered the edited synthetic draft while the saved library stayed unchanged. No Save/Discard/Cancel choice appeared, so the Q8 dirty-quit gate failed. Q9 has passed source/local checks only; its packaged runtime class and quit/recovery behavior remain unverified. No Q9 hosted CI result is claimed, and publication remains on hold. Neutral Core does not generate answers; the shared optional-writer fixtures do not activate generation in this edition.

Neutral Core does not implement full generative answers, Studio/audio/video artifacts, web/video/cloud imports, OCR, sharing, or complete reference behavior. Broader accessibility, macOS 14, and Intel acceptance remain open. See [testing](TESTING.md), [parity](PARITY.md), and [publication history](docs/PUBLICATION.md).
