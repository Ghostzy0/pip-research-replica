# Planned public repository profiles

**Status: planned, not created or published.** This document records the requested release shape; it is not evidence that either repository, a release, or a public source pin exists. Do not infer parity acceptance from the profile names.

## Repository and artifact profiles

| Planned repository | Intended release artifacts | Current product aliases | Qualification boundary |
| --- | --- | --- | --- |
| `pip-research` | Three artifacts: Neutral Plus, Pip Core and Pip Plus | `ResearchBaselineEnhanced`, `PipResearch`, `PipResearchEnhanced` | The four-package suite passed 67 tests with one opt-in live skip (68 cases total); stripped local packages passed private-path scans and signature verification. Both v3 profile exports then passed independent fresh local-clone tests (same 67+1 result), and the three custom-profile products built and signature-verified. Bundle metadata/resources matched and executable scans were clean. These are local checks, not public releases. Native manual-notes interaction, broader accessibility acceptance and independent clean-clone review of the current export remains pending. |
| `pip-research-replica` | One artifact: Neutral Core | `ResearchBaseline` | The neutral interface is not yet accepted as a faithful target recreation. Reference-parity gaps and layout work remain under specialist review. |

The owner aliases are product-profile names. Existing executable product names, display names, bundle identifiers and versions remain those in [the edition matrix](EDITION-MATRIX.md). The planned profile split changes distribution metadata and release selection; it does not create separate research engines.

## Shared source and public traceability

The custom export contains only the three owned executable entry points (Neutral Plus, Pip Core and Pip Plus); the replica export contains only the Neutral Core entry point. Both include the same `ResearchCore` and `ResearchDesktop` sources and tests, with byte-identical shared-core files recorded in `SHARED-CORE-SHA256.json`. This lets both repositories run the shared regression suite without exporting unowned executable entry points. Record the public shared-code pin using those file hashes after publication. Keep repository-specific README, changelog, package metadata and release commands distinct.

Public source history must be a clean export. Do not include the private monorepo history, its commit identifiers, private audit/evidence paths, restricted motion code or reference captures. This plan does not authorize claiming a public code pin before the repositories and manifests exist.

## Acceptance boundaries

The shared functional core and four-target default tests are common regression evidence, not proof that each interface reproduces a reference product. Manual notes are implemented across all four variants, but full native UI review is pending. One controlled SIGTERM recovery restored and saved an exact synthetic Unicode note after relaunch; Cmd-Q while the dirty editor modal was open showed no visible quit or alert and remains an unresolved limitation. Neutral Core has a separate faithful-recreation acceptance gate. The current Pip Plus native review covers one synthetic workflow only. A targeted request to the pinned Qwen model returned valid JSON but omitted required citation IDs and falsely claimed disagreeing sources agreed; strict validation rejected it without saving a draft. Local generation remains off by default and unaccepted. See [testing](../TESTING.md) and [parity](../PARITY.md) for current evidence and gaps.
