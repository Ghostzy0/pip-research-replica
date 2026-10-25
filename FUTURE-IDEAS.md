# Roadmap

- Keep the absent-fact failure visible: the writer repeats weekday hours when asked about public holidays without acknowledging missing support. Do not weaken expectations or the strict validator to hide this gap; retain the experimental/default-off boundary. Conflict-plus-persistence and hostile-source passed in the opt-in run; a raw Qwen3.5 0.8B comparison repeated the missing-support failure and was not adopted.
- Continue native coverage for remaining routes, including Dock, window close, pending writes, failed saves and multiwindow behavior. Q9 packaged tests passed startup and dirty Cmd-Q Cancel/Save/restart on all four variants; Pip Core also passed menu Discard/restart. These bounded results do not cover every AppKit termination route.
- Complete lawful reference comparisons and broader accessibility/device acceptance, including VoiceOver, reduced motion, macOS 14, and Intel where available.
- Fix and regress fact-bearing retrieval without weakening exact source anchors or abstention. Neutral Plus omitted the 18:00/19:00 facts while citing 0:45/0:44 spans; see [public issue #6](https://github.com/ghostzy0/pip-research/issues/6). The Q10 Core retrieval fix passed local qualification; hosted Q10 CI and v7 native checks remain pending.
- Evaluate additional local source formats and OCR with explicit local/online data boundaries.
- Measure larger libraries before selecting a persistent vector/full-text index or expanding language support.

These are proposals and open acceptance work, not shipped capabilities or promised dates. The four existing editions remain separate releases over the shared implementation.
