# Foundation and local inference provenance

All four variants are original native Swift implementations, not redistributed NotebookLM/Gemini Notebook. They use Foundation, SwiftUI/AppKit, PDFKit, NaturalLanguage and CryptoKit supplied by macOS. No third-party package, font or model weight is bundled. The original unthemed baseline and Pip UI share the same tested local core and have separate bundle/data identities.

Source review considered [ZoloRAG](https://github.com/zosmaai/zolorag/tree/3e780f412773cce16ddccabe6a877f6bcacbe317) at `3e780f412773cce16ddccabe6a877f6bcacbe317` (README states MIT but this tree lacks a LICENSE file) and MIT [OpenNotebookLM](https://github.com/tom1030507/OpenNotebookLM/tree/0cc8a3c687214d352f68f49972d861e5d93c60c3) at `0cc8a3c687214d352f68f49972d861e5d93c60c3` (LICENSE SHA256 `17aa2116b1164d92eaa4aa2dee0486e67ff8d928e67591cbf13099a52f0eee18`). Neither app's code/assets are included. The in-process native architecture avoids the latter's server/account deployment and extends beyond the former's one-PDF/in-memory-chat architecture.

## Evidence core

App-owned originals are hashed; passages retain immutable source/page/heading/UTF16 anchors. Exact text is quoted, not fabricated by a language model. The operating system's English sentence embedding is used where already available; the app does not request a download. Availability and test coverage are recorded in TESTING. Lexical fallback remains useful and explicitly labelled. Embeddings and citations aid finding/checking evidence; they do not prove truth or complete retrieval.

## Optional local drafting

An explicitly requested draft can use a separately installed [Ollama](https://ollama.com/) local process and [qwen3:0.6b-q4_K_M](https://ollama.com/library/qwen3:0.6b-q4_K_M). This optional runtime is not needed for imports, search, evidence answers, citation navigation, persistence or export. It is not bundled, automatically installed or downloaded by the app. No cloud endpoint/account/provider credentials are used.

Read-only provenance of the test machine's already-installed artifact on 23 October 2026:

- Runtime Ollama `0.40.6`; [runtime source licence](https://github.com/ollama/ollama/blob/main/LICENSE): MIT.
- Weight blob SHA256 `7f4030143c1c477224c5434f8272c662a8b042079a0a584f0a27a1684fe2e1fa`, 522,640,096 bytes.
- Local manifest SHA256 `6f76d4346c34ba89df6e137fb661b4bb4daf322c1151b6ef0dfda981070a851f`; displayed model id `7df6b6e09427`.
- Apache-2.0 licence layer SHA256 `d18a5cc71b84bc4af394a31116bd3932b42241de70c77d2b76d69a314ec8aa12`, Copyright 2024 Alibaba Cloud. [Official Qwen3-0.6B model card](https://huggingface.co/Qwen/Qwen3-0.6B) independently labels Apache-2.0.

These pins identify the artifact inspected; mutable registry tags can change. No weight redistributability claim is extended to unrelated models/quantisations. Runtime inference and output quality are separate evidence, recorded only when actually tested. Generated drafts can make unsupported claims even when every citation number is valid; the UI labels them for verification.
