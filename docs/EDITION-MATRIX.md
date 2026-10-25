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

The Notes source enforces one editor owner per notebook and keeps each scene's captured target. Q8's sheet policy and its native dirty-quit failure remain historical. Q9 gates termination before `super.terminate` can tear down Notes sheets, installs a typed bridge through an early principal-class subclass, and uses guarded one-shot approval for native reentry; direct system queries use `terminateLater` and one reply. Unavailable active Notes sessions and dirty `.close` requests fail closed; pre-model startup can terminate before any Notes session exists. Thirteen Q9 source regressions cover delegate and ingress paths. Q9 passed 91 local cases (88 passed, 3 live-writer skips), all four local package checks, and hosted CI on both exact public heads (91/88/3/0). All four Q9 variants passed startup and dirty Cmd-Q Cancel/Save/restart; Pip Core also passed menu Discard/restart. Neutral Plus mechanics passed, but its fact-bearing answer/excerpt omitted 18:00/19:00 while citing 0:45/0:44 spans despite opening the originals. See [public issue #6](https://github.com/ghostzy0/pip-research/issues/6). Q10 local qualification completed 96 cases (93 passed, 3 skipped, 0 failed); hosted Q10 CI and v7 native checks remain pending, so the overall release remains on hold. See [current testing evidence](../TESTING.md).

Evidence mode needs no server, account, model, or third-party Swift package. Optional local drafting requires a separately installed loopback Ollama service and an exact fingerprint-checked model; it stays experimental and off by default. One bounded synthetic 1.7B probe returned the required citation IDs but misleadingly interpreted source dates. In separate opt-in tests, conflict-plus-persistence and hostile-source passed; the absent-fact case failed two expectations. Asked for public-holiday hours, it returned `The station garden closes at 18:00 on weekdays [1].` It did not explicitly invent holiday hours, but failed to acknowledge that the source gives weekday hours only and no public-holiday information. A raw Qwen3.5 0.8B comparison repeated that missing-support failure and was not adopted. No model was accepted; no general grounding claim is made.

## Data compatibility and edition changes

The editions use separate Application Support directories and have no cross-edition migration interface. Back up the complete folder with the app closed before changing editions or versions. New source versions are `0.1.2` for Core and `0.2.1` for Plus. The public 23 October packages were `0.1.1` and `0.2.0`; current upgrade behavior from those exact packages and recovery-sidecar compatibility still require release verification. Do not downgrade or open a newer Plus library in an older writer unless a tested compatibility procedure explicitly covers it. No package may overwrite another edition's library.

Bundle identifiers, versions, directories and feature boundaries must be checked against the actual frozen packages and profile manifests. This matrix states intended identities and is not itself package/runtime evidence.
