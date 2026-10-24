# Pip Research edition matrix

The four editions share `ResearchCore` and `ResearchDesktop`. Each selects its own interface, feature capability, bundle identifier, and Application Support folder. Neutral Core is released from `pip-research-replica`; Neutral Plus, Pip Core, and Pip Plus are released from `pip-research`.

| Variant | Build alias | Product | Display name | Bundle identifier | Data folder | Current source version |
|---|---|---|---|---|---|---:|
| Neutral Core | `baseline` | `ResearchBaseline` | Research Baseline | `uk.pipreps.research.baseline` | `Research Baseline` | `0.1.2` |
| Neutral Plus | `baseline-enhanced` | `ResearchBaselineEnhanced` | Research Baseline Enhanced | `uk.pipreps.research.baseline.enhanced` | `Research Baseline Enhanced` | `0.2.1` |
| Pip Core | `pip` | `PipResearch` | Pip Research | `uk.pipreps.research` | `Pip Research` | `0.1.2` |
| Pip Plus | `pip-enhanced` | `PipResearchEnhanced` | Pip Research Enhanced | `uk.pipreps.research.enhanced` | `Pip Research Enhanced` | `0.2.1` |

These are source-declared versions for the next release batch. They do not mean that those versions have been published. The historical `research-alpha-2026.10.23` releases remain unchanged; see [publication history](PUBLICATION.md).

All variants provide local notebooks, source imports, evidence retrieval, citation navigation, manual notes, and Markdown export. Plus variants add notebook-scoped search over saved questions/excerpts and saved exact citations with optional labels and annotations. Neutral Plus and Pip Plus use the same additions. Core editions do not expose Plus controls. Each edition has a separate default data folder; switching editions does not migrate or merge data.

The Notes source enforces one editor owner per notebook and keeps each scene's captured target. A shared AppKit termination delegate routes normal termination through the deferred Save/Discard/Cancel coordinator; four source tests cover its exactly-once reply behavior. Native Dock, menu, Cmd-Q, window-close, and multiwindow acceptance remains pending. See [current testing evidence](../TESTING.md).

Evidence mode needs no server, account, model, or third-party Swift package. Optional local drafting requires a separately installed loopback Ollama service and an exact fingerprint-checked model; it stays experimental and off by default. One bounded synthetic 1.7B probe returned the required citation IDs but misleadingly interpreted source dates. In separate opt-in tests, conflict-plus-persistence and hostile-source passed; the absent-fact case failed two expectations. Asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` It did not explicitly invent holiday hours, but failed to acknowledge that the source gives weekday hours only and no public-holiday information. A raw Qwen3.5 0.8B comparison repeated that missing-support failure and was not adopted. No model was accepted; no general grounding claim is made.

## Data compatibility and edition changes

The editions use separate Application Support directories and have no cross-edition migration interface. Back up the complete folder with the app closed before changing editions or versions. New source versions are `0.1.2` for Core and `0.2.1` for Plus. The public 23 October packages were `0.1.1` and `0.2.0`; current upgrade behavior from those exact packages and recovery-sidecar compatibility still require release verification. Do not downgrade or open a newer Plus library in an older writer unless a tested compatibility procedure explicitly covers it. No package may overwrite another edition's library.

Bundle identifiers, versions, directories and feature boundaries must be checked against the actual frozen packages and profile manifests. This matrix states intended identities and is not itself package/runtime evidence.
