# Pip Research edition matrix

The four products use the shared `ResearchCore` and `ResearchDesktop` implementation. Each executable selects its own visual entry point, feature capability and application-support directory. All four packages were rebuilt with debug information stripped before signing, scanned for private-path strings, and signature-verified from the qualification snapshot listed in [TESTING](../TESTING.md). Both v3 profile exports passed independent fresh local-clone tests (67 passed, one opt-in live skip, 68 cases) and built/signature-verified their owned products: three in custom, one in replica. Bundle metadata/resources matched and executable scans found no private path strings. These are local checks; public repository publication remains pending. The primary synthetic saved-evidence workflow passed in Pip Research Enhanced `0.2.0`; current neutral enhanced and broader current-package acceptance remains pending.

| Build command | Product | Display name | Bundle identifier | Application Support directory | Version |
| --- | --- | --- | --- | --- | --- |
| `./scripts/build.sh baseline` | `ResearchBaseline` (Neutral Core) | Research Baseline | `uk.pipreps.research.baseline` | `Research Baseline` | `0.1.1` |
| `./scripts/build.sh pip` | `PipResearch` (Pip Core) | Pip Research | `uk.pipreps.research` | `Pip Research` | `0.1.1` |
| `./scripts/build.sh baseline-enhanced` | `ResearchBaselineEnhanced` (Neutral Plus) | Research Baseline Enhanced | `uk.pipreps.research.baseline.enhanced` | `Research Baseline Enhanced` | `0.2.0` |
| `./scripts/build.sh pip-enhanced` | `PipResearchEnhanced` (Pip Plus) | Pip Research Enhanced | `uk.pipreps.research.enhanced` | `Pip Research Enhanced` | `0.2.0` |

Owner terminology aliases: Neutral Core = `ResearchBaseline`; Neutral Plus = `ResearchBaselineEnhanced`; Pip Core = `PipResearch`; Pip Plus = `PipResearchEnhanced`. The aliases describe edition roles; package names, bundle identifiers and display names remain as listed above.

All four editions provide notebook-scoped manual notes, the shared source import/evidence/citation/export workflow, and per-edition storage. The Pip editions use the original Pip interface; the baseline editions use the neutral interface. Enhanced editions additionally enable saved-question and evidence search plus saved citation excerpts with optional labels and annotations. Capability checks gate those enhanced-only operations in the shared model, so baseline executables do not expose or enable them. Separate directories keep each edition's library isolated. The manual Notes UI is implemented, but native interaction acceptance remains pending. A bounded native SIGTERM recovery check restored and saved one synthetic Unicode note after relaunch; Cmd-Q while the dirty editor modal was open produced no visible quit or alert, an unresolved limitation.

The core source build has no third-party Swift package dependencies. Local drafting is optional and requires a separately installed Ollama service and a user-installed compatible model. No model weights are bundled or downloaded by these commands. See [Local drafting](LOCAL-DRAFTING.md) and [Security](../SECURITY.md) for the optional loopback boundary.

## Moving between editions or versions

Each edition uses a separate default Application Support folder. The apps do not automatically migrate or merge libraries across editions, and there is no cross-edition migration interface. Back up the entire folder with its app closed before changing versions or editions. Do not open an enhanced-edition library with a pre-`0.1.1` writer: older writers may ignore or discard fields they do not recognize. The current `0.1.1` baseline can preserve saved excerpts while its baseline interface hides the enhanced features. This describes the current compatibility boundary; it is not a promise of automatic cross-variant migration.

Package names, identifiers, versions and build commands are taken from `Package.swift`, the four app entry points, `AppModel.swift`, `scripts/build.sh` and `scripts/package.sh`. Verify the built app's `Info.plist` and package contents before release; this source table is not build or runtime evidence.

The proposed public repository split and release profiles are documented in [Two repositories](TWO-REPOSITORIES.md). Those repositories have not yet been created.
