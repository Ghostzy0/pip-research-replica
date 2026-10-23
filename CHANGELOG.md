# Changelog

## 0.1.1-alpha.1 — experimental, partial workflow recreation

This repository profile contains one runnable Neutral Core app, Research Baseline. It is an original native implementation of local notebooks, copied PDF/TXT/Markdown sources, source selection, evidence chats, exact citation navigation and Markdown notebook export.

Current source implements manual research notes and interrupted-session draft recovery. One controlled native SIGTERM recovery flow passed for a synthetic Unicode note; a dirty-modal Cmd-Q attempt showed no visible quit or alert and remains unresolved.

The shared default suite completed 68 cases (67 passed, one opt-in live test skipped, zero failures). After the package audit found local debug metadata in the first artifacts, all four bundles were refreshed from the qualified release binaries with local debug metadata stripped before signing. Refreshed bundles passed signature and private-path checks with the original LICENSE and NOTICES bundled.

Both v3 profile exports subsequently passed independent fresh local-clone test/build/signature checks: three custom products and one replica product. Native manual-notes interaction review, Neutral Core faithful-recreation acceptance, broader interface accessibility review and public remote publication remain pending.

Neutral Core has not passed the separate faithful-reference recreation gate. It does not provide NotebookLM's full notes, web/video import, audio overview or AI Studio workflows. Optional local Qwen drafting remains off by default and unaccepted; after correcting the request grammar and schema, the tested writer returned valid JSON without citations and asserted an unsupported agreement between sources. The app rejected it, saved no draft and unloaded the model.

No Google or NotebookLM assets, code or branding are included. This is not a full-equivalence or stable-production claim.
