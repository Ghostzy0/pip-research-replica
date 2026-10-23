# Research Notebook

An independent native macOS recreation of a focused NotebookLM / Gemini Notebook workflow: ask questions about local documents, inspect supporting passages, follow citations to their source and export the notebook. It is not affiliated with or endorsed by Google, NotebookLM, Gemini or Apple.

**Experimental, partial workflow recreation.** This repository exports one runnable Neutral Core app:

| Build alias | Swift product | App | Version |
| --- | --- | --- | --- |
| baseline | ResearchBaseline | Research Baseline | 0.1.1 |

The current source implements editable manual research notes and recovery of unsaved note edits after an interrupted session. The shared test suite and both v3 profile clean-clone checks passed; native manual-notes interaction review remains pending. One controlled SIGTERM recovery test restored and saved a synthetic Unicode note after relaunch; Cmd-Q while the dirty editor modal was open showed no visible quit or alert, which remains unresolved.

The shared default suite completed 68 cases: 67 passed, one opt-in live test was skipped, and none failed. Both v3 profile exports passed independent fresh local-clone tests (67 passed, one opt-in live skip, 68 total cases); the custom profile built and signature-verified three products and the replica profile built and signature-verified one. Bundle metadata/resources matched and executable private-path scans were clean. The source is published in this repository. Independent final export review and hosted macOS 15 / Swift 6.1 tests and release-product builds passed; see [publication and package verification](docs/PUBLICATION.md). Package scripts remove local debug metadata from the copied executable before signing. This does not establish faithful reference parity, native manual-notes acceptance or accepted local generation.

## What works

- Create local notebooks and import copied PDF, UTF-8 TXT and Markdown sources.
- Write and edit manual research notes; recover unsaved note edits after an interrupted session.
- Choose the sources used for a question and retain evidence chats after restart.
- Inspect exact quoted passages, source pages and headings; open the original PDF at a cited page.
- Compare conflicting statements, see when no evidence was found and export notebook evidence as Markdown.
- Use macOS-native file import, text selection and PDFKit passage navigation.

This implements useful local-source and citation-navigation behavior with original code. It does not reproduce the complete NotebookLM/Gemini Notebook product or visual identity.

## Build

Requires macOS 14+ and Swift 6+. No third-party Swift packages, accounts, server or model weights are needed for evidence workflows.

~~~sh
swift test --jobs 2
./scripts/build.sh baseline
open 'dist/Research Baseline.app'
~~~

The app is locally ad-hoc signed, not Developer ID signed or notarised. Do not disable macOS security globally. See [AI setup](docs/AI-SETUP.md), [testing](TESTING.md), [parity](PARITY.md) and [the edition matrix](docs/EDITION-MATRIX.md).

## Local data and limits

Imported sources are copied into the Research Baseline Application Support folder. Notebook data is readable JSON and is not encrypted. Back up the full folder with the app closed. The optional local Qwen drafting path is off by default and unaccepted; after correcting the request grammar and schema, the tested model returned valid JSON but omitted required citations and made an unsupported agreement claim. The app rejected it and saved no draft. See [security](SECURITY.md) and [local drafting](docs/LOCAL-DRAFTING.md).

The app does not provide built-in OCR, webpage/video/cloud imports, audio overviews, AI Studio or other generated artifacts, sharing or complete reference parity. Markdown notebook export is available, but there is no full Studio export workflow. Answers and citations need human review; retrieval can miss relevant information. Broader accessibility, device and reference-workflow acceptance remains pending.

This project is an independent original implementation inspired by a narrow NotebookLM/Gemini Notebook workflow. It does not use Google's assets, code or branding.
