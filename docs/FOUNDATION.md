# Foundation and local inference provenance

All four variants are original native Swift implementations, not redistributed NotebookLM/Gemini Notebook. They use Foundation, SwiftUI/AppKit, PDFKit, NaturalLanguage and CryptoKit supplied by macOS. No third-party package, font or model weight is bundled. The original unthemed baseline and Pip UI share the same tested local core and have separate bundle/data identities.

Source review considered [ZoloRAG](https://github.com/zosmaai/zolorag/tree/3e780f412773cce16ddccabe6a877f6bcacbe317) at `3e780f412773cce16ddccabe6a877f6bcacbe317` (README states MIT but this tree lacks a LICENSE file) and MIT [OpenNotebookLM](https://github.com/tom1030507/OpenNotebookLM/tree/0cc8a3c687214d352f68f49972d861e5d93c60c3) at `0cc8a3c687214d352f68f49972d861e5d93c60c3` (LICENSE SHA256 `17aa2116b1164d92eaa4aa2dee0486e67ff8d928e67591cbf13099a52f0eee18`). Neither app's code/assets are included. The in-process native architecture avoids the latter's server/account deployment and extends beyond the former's one-PDF/in-memory-chat architecture.

## Evidence core

App-owned originals are hashed; passages retain immutable source/page/heading/UTF16 anchors. Exact text is quoted, not fabricated by a language model. The operating system's English sentence embedding is used where already available; the app does not request a download. Availability and test coverage are recorded in TESTING. Lexical fallback remains useful and explicitly labelled. Embeddings and citations aid finding/checking evidence; they do not prove truth or complete retrieval.

## Optional local drafting

An explicitly requested draft can use a separately installed [Ollama](https://ollama.com/) local process and the fingerprint-checked Qwen3 1.7B quantisation. This optional runtime is not needed for imports, search, evidence answers, citation navigation, persistence or export. It is not bundled, automatically installed or downloaded by the app. No cloud endpoint/account/provider credentials are used.

### Current model pin — inspected 24 October 2026

- Model: [`qwen3:1.7b-q4_K_M`](https://ollama.com/library/qwen3:1.7b-q4_K_M).
- Inspected weight blob: 1,359,279,776 bytes; SHA-256 `3d0b790534fe4b79525fc3692950408dca41171676ed7e21db57af5c65ef6ab6`.
- Ollama manifest fingerprint required by the app: `8f68893c685c3ddff2aa3fffce2aa60a30bb2da65ca488b61fff134a4d1730e7`.
- The checked licence layer is Apache-2.0, SHA-256 `d18a5cc71b84bc4af394a31116bd3932b42241de70c77d2b76d69a314ec8aa12`, copyright 2024 Alibaba Cloud. See the [Qwen3 1.7B model page](https://ollama.com/library/qwen3:1.7b-q4_K_M) and its [licence layer](https://ollama.com/library/qwen3:1.7b/blobs/d18a5cc71b84).

### Historical model pin — inspected 23 October 2026

The earlier production pin was [`qwen3:0.6b-q4_K_M`](https://ollama.com/library/qwen3:0.6b-q4_K_M). The inspected weight blob was 522,640,096 bytes, SHA-256 `7f4030143c1c477224c5434f8272c662a8b042079a0a584f0a27a1684fe2e1fa`; the model fingerprint was `7df6b6e09427a769808717c0a93cadc4ae99ed4eb8bf5ca557c90846becea435`. Its checked Apache-2.0 licence layer had SHA-256 `d18a5cc71b84bc4af394a31116bd3932b42241de70c77d2b76d69a314ec8aa12`, copyright 2024 Alibaba Cloud. See the [Qwen3 model card](https://huggingface.co/Qwen/Qwen3-0.6B).

Ollama `0.40.6` was the runtime observed on 23 October; this is historical evidence, not a current minimum-version claim. The app checks the reported manifest fingerprint before sending passages. Registry tags are mutable, so a changed artifact is blocked until reviewed. No weight redistributability claim is extended to other models or quantisations. Runtime behavior and output quality are separate: a later 1.7B run persisted one synthetic conflict answer, but its source-date interpretation was misleading, and an absent-fact live case failed two expectations. Drafting stays optional, experimental, and off by default; exact boundaries are in [Local drafting](LOCAL-DRAFTING.md).
