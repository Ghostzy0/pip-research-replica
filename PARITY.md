# Workflow scope and parity

**Updated 24 October 2026.** Pip Research is an original local implementation of a limited NotebookLM / Gemini Notebook workflow. It is not affiliated with Google and does not use Google's code, assets, or branding.

All four editions implement local notebooks; copied PDF, UTF-8 TXT and Markdown sources; source selection; durable evidence chats; passage, page, heading and UTF-16 citation navigation; manual notebook notes; source reindex/removal; and Markdown export. Enhanced editions add notebook-scoped search over saved questions and excerpts, with labelled/annotated exact citations. The four product identities and folders are listed in [the edition matrix](docs/EDITION-MATRIX.md).

Evidence responses are extractive and help locate source text. They do not prove that a statement is true or complete. Retrieval may miss relevant content; an empty result is not proof of absence. Compare conflicting passages in their original context.

## Reference evidence and gaps

A limited signed-in synthetic reference walkthrough previously observed multi-source answering, citation chips, and a source passage card. The absent-fact query was unfinished. This is narrow workflow evidence and does not establish current geometry or full reference behavior. Neutral Core is a partial recreation, not an accepted 1:1 or full product recreation.

The app does not implement the full set of generated summaries and answers, Studio/audio/video artifacts, web/video/cloud imports, OCR, sharing/sync, or provider/account workflows. Notes source enforces one editor owner per notebook and preserves each scene's captured target. A shared AppKit termination delegate now routes normal app termination through the deferred Save/Discard/Cancel coordinator and replies once; four source tests cover the bridge. Native Dock/menu/Cmd-Q/window-close and alert behavior still need packaged acceptance.

Optional local drafting is disabled by default and remains experimental. One bounded synthetic Qwen3 1.7B probe returned valid JSON with the requested citation IDs and named a source conflict, but introduced a misleading interpretation of source dates. Separately, an opt-in run passed the conflict-plus-persistence and hostile-source cases; the absent-fact case failed two expectations: asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` without acknowledging that the source only gives weekday hours. It did not explicitly invent holiday hours. That one persistence scenario passed, but general grounding and broader product persistence are not established. See [testing](TESTING.md) and [local drafting](docs/LOCAL-DRAFTING.md).

Broader accessibility, VoiceOver, reduced-motion human review, macOS 14 and Intel device acceptance remain open. These gaps are not converted into passes by a compile, test suite, screenshot, static scan, or release tag.
