# Optional local drafting

**Status: experimental and unaccepted.** The core notebook/evidence workflow works without this feature. Drafting is off by default and sends selected question/passages only to an already-running **local** Ollama process after explicit opt-in. An earlier production-shaped request returned non-JSON inner content and was rejected as `malformedResponse`. After correcting the request's JSON schema and citation instructions, a targeted request to the pinned Qwen 0.6b model returned valid JSON but omitted every required citation marker and incorrectly claimed that disagreeing sources agreed. The unchanged strict validator rejected it; no draft was saved and the model unloaded. Successful generated drafting has not been demonstrated. The app never downloads weights, starts a paid provider, uses an account or silently switches to a cloud service.

## Setup

1. Install Ollama from its [official website](https://ollama.com/) and start the local service. Follow its current official instructions and licence.
2. Install the exact supported public model using `ollama pull qwen3:0.6b-q4_K_M` (about 523 MB). Check the [model page](https://ollama.com/library/qwen3:0.6b-q4_K_M), its Apache-2.0 licence and [artifact provenance](FOUNDATION.md).
3. Check `ollama list`. The app requires manifest fingerprint `7df6b6e09427a769808717c0a93cadc4ae99ed4eb8bf5ca557c90846becea435`. A mutable registry tag may change; if it differs, the app blocks drafting before sending passages. Use evidence mode and review a supported update rather than renaming an arbitrary model to bypass the check.
4. The tested model currently fails strict attribution and content validation. Do not install the model expecting an accepted generated draft. Evidence mode and manual notes work independently; do not bypass validation or treat a rejected answer as saved.

No remote installer script or global security setting is needed. Ollama is separately installed; it is not bundled in release apps. The test machine's installed runtime and weight/licence digests are recorded in FOUNDATION. Do not install a model expecting this build to produce an accepted draft. Successful fixture tests are not proof of real inference or output quality; TESTING records actual runs separately.

## Boundary and limits

The fixed endpoint is `http://127.0.0.1:11434`; arbitrary remote endpoints are unsupported. Each explicit request first makes a bounded metadata-only `/api/tags` check, then posts the question and exact numbered excerpts to `/api/chat`. Redirects, authentication, cookies, credentials, proxies and tool calls are blocked/unused. The local daemon is trusted as software running under your account; checking its reported fingerprint does not defend against a malicious daemon or a concurrent model replacement.

Maximum input: 2,000 question bytes, 8 citations, 10,000 passage bytes, 14,000 combined system/user bytes. Generation uses a bounded 16K context and 768 output budget, deterministic settings, 5-second metadata + 55-second draft deadlines and a 128 KiB response cap. Large inputs fail explicitly without quietly dropping or renumbering sources. Stop cancels the client request; the separate local daemon controls its own compute cleanup.

The request uses an ordinary JSON-string schema and supplies canonical citation tokens in the prompt; it does not use the prior regex-shaped JSON grammar. The independent response validator remains unchanged and checks JSON shape, nonempty lines, byte bounds and exact supplied `[n]` IDs. The tested model omitted those IDs and contradicted the sources, so the response was rejected. Even a syntactically accepted draft would not prove factual grounding. Sources and questions are untrusted data, not executable instructions. Generated content is displayed as plain text with no tool execution or automatic URL opening. Successfully saved drafts are labelled separately in exports.
