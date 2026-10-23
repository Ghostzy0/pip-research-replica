## Current published source checks — 23 October 2026

Both public source profiles passed hosted macOS 15.7.9 arm64 / Swift 6.1.2 CI: 67 tests passed, one intentional opt-in live test skipped, zero failures, followed by all owned release-product builds. [This profile's passing run](https://github.com/Ghostzy0/pip-research-replica/actions/runs/39892438845). A single static-function call was qualified to remove an ambiguity found by Swift 6.1.2. The newer local four-product package batch passed the same 67-pass/1-skip suite on macOS 27.0.1 / Swift 6.4. See [current package hashes and evidence boundaries](docs/PUBLICATION.md); older hashes below are historical.

This repository exports one runnable executable: ResearchBaseline. Tests exercise the shared core and desktop code included here; other edition entry points are excluded.

# Verification

## Current notes and four-package qualification batch

On 23 October 2026, a qualification snapshot containing the shared manual-note implementation, source, tests and build scripts passed **67 tests**, skipped **one opt-in live test**, and had zero failures (**68 total cases**) on an Apple silicon macOS host. This comprises 46 ResearchCore tests and 21 ResearchDesktop tests passed, with the opt-in test among 22 Desktop cases. The original four packages passed `codesign --verify --deep --strict`. A subsequent artifact audit found private build paths in executable debug metadata. The packages were rebuilt with debug information stripped before signing, scanned for private-path strings, and passed signature verification again. These local outputs are not public release assets. In a separate v3 clean-clone review, both fresh profile exports passed `swift test --jobs 2` (67 passed, one opt-in live test skipped, 68 total cases), then built and signature-verified all three custom-profile products and the one replica-profile product. Bundle resources and metadata matched, and executable scans found no private path strings. This local reproducibility evidence does not establish native manual-notes UI acceptance, Neutral Core faithful-recreation acceptance, or public repository publication.

The following are SHA-256 checksums of the locally audited, stripped and ad-hoc signed package executables. They are not checksums for publicly published release assets. Final package receipt SHA-256: `297e978927b18d07ef7d1324b610bd680f9821230a92064368ec05eb42e34154`.

| Edition and version | Executable SHA-256 |
| --- | --- |
| Research Baseline `0.1.1` | `199cc31ac3dddf7bf09c5df949773b1fd5bea006dbd1b4b33aa85f5bf3d322ba` |
| Pip Research `0.1.1` | `afbe455ecdcd34a4e93efe2b2df892c727aa0a967a945d87b667a8583a71ecb8` |
| Research Baseline Enhanced `0.2.0` | `fb2cf448ad1ea2323d4255ceeb9165621d4b7cf7c11bdcfc54133ee3b2074ab3` |
| Pip Research Enhanced `0.2.0` | `78e7c0607493402860ef60ea8112175d0d926b3aa5433510a534fcf74674117a` |

Manual notes are notebook-scoped, available in all four editions and included in notebook Markdown export. Eleven new core tests cover persistence, notebook boundaries, deletion, legacy schema, limits, validation, failure handling and export. Dirty note-editor drafts are atomically stored per notebook under `.note-drafts/` in app-owned storage with an explicit restore/discard prompt. Recent UI hard-check fixes address edits during busy save, a note deleted in another window, and leaving a recovery prompt for later. A native check passed one controlled SIGTERM recovery flow for a synthetic Unicode note: after relaunch, the exact title and body were restored, saved, and the recovery sidecar cleared. Cmd-Q while the dirty editor modal was open produced no visible quit or alert; that limitation remains unresolved. This is a bounded native check, not general crash or in-flight-write recovery acceptance.

## Earlier frozen four-variant source and packages

On 23 October 2026, the frozen four-variant source snapshot passed the default Swift suite with **56 tests passed, one opt-in live-writer test skipped, and zero failures** on macOS 27.0.1 arm64 / Swift 6.4. The four release apps were built, packaged and ad-hoc code-signature-verified: Research Baseline `0.1.1`, Pip Research `0.1.1`, Research Baseline Enhanced `0.2.0`, and Pip Research Enhanced `0.2.0`. This does not establish clean public-clone reproducibility or complete native interaction acceptance; those checks remain pending below.

An earlier optional Ollama/Qwen request was rejected because its inner content was not JSON. After correcting the request schema and citation instructions, a targeted request to the pinned model produced valid JSON but no citation markers and an unsupported claim that the contradictory sources agreed. The unchanged validator rejected it; no draft was saved and the model was unloaded. Optional generation remains unaccepted and off by default. Passing fixture/transport tests do not establish real-generation correctness or grounding.

The available round-two rendered review evidence for the earlier `0.1.0` build does not qualify current packages. A later native run passed the primary synthetic saved-evidence workflow in Pip Research Enhanced `0.2.0`: it saved an exact citation excerpt, edited its label/note, found the note through notebook history search, reopened its source, exported and retained the excerpt after restart. Current neutral enhanced acceptance and broader accessibility/motion/device coverage remain pending. This limited pass is not full interface qualification.

Historical pre-enhancement suite: macOS27.0.1 arm64, Swift6.4. Before enhancement changes, `swift test --jobs 2` ran43 cases with0 failures and1 intentional opt-in live skip:24 core,13 local-draft transport fixtures,5 native-state integration cases and1 optional live test. Those results do not qualify the current source snapshot.

Core coverage includes copied sources, restart/persistence, hash/reindex/duplicate lifecycle, corrupt state/unsafe paths, exact UTF16/Unicode/heading/PDF-page anchors, contradictory/absent facts, source subsets, injection inertness, exclusive library locks, cleanup failures, draft persistence and current-original integrity. UI-state tests cover corrupt startup, partial/cancelled imports, concurrent initialization and captured import/rename targets. Transport fixtures exercise fixed loopback metadata/draft requests, exact fingerprint preflight, no source POST on mismatch, redirects, bounds, deadlines/cancellation and citation syntax.

Actual OS English sentence embeddings were available. Bounded car/automobile and spend/budget recall fixtures passed alongside negative/absence checks. This is not universal semantic precision/recall or cross-language acceptance.

An earlier packaged neutral baseline ran synthetic MD/TXT/PDF imports, evidence questions, exact selected text, original PDF page/highlight, Escape focus return, restart, notebook create/rename/named removal, both conflicting 18:00/19:00 citations and Markdown export with source hashes. Its exported sample was 2,422 bytes. No reference assets are distributed.

On an earlier pre-enhancement build, a real optional local Qwen request was rejected for missing attribution; no draft was saved, evidence remained and the model unloaded. That older result predates the current request/response contract. The current targeted request result is described above: valid JSON still failed attribution and contradicted its sources. Real generation success has not been demonstrated; transport fixtures do not prove grounding.

Reproduce default tests with `swift test --jobs 2`. Opt-in real writer test: `PIP_RESEARCH_TEST_LOCAL_DRAFT=1 swift test --filter LocalDraftLiveTests --jobs 2`, only with the documented compatible local runtime/model; it sends its synthetic fixture to that local service and has not produced an accepted draft in the tested pinned-model request described above. Build only the aliases listed in this repository's README and DISTRIBUTION.json; run matching sample scenarios. Enhanced search/excerpt tests passed in the frozen default suite; broader interactive Pip/enhanced workflows and accessibility coverage remain pending.

No claimed Intel, older-macOS runtime, VoiceOver, full reference parity, notarisation, energy efficiency or stable-production acceptance. A limited free signed-in reference walkthrough observed multi-source answers/citation navigation; an absent-fact query remained unfinished.
