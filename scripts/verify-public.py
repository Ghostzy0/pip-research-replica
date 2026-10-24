#!/usr/bin/env python3
"""Verify one clean profile export. This is a boundary check, not build/runtime acceptance."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

PROFILES = {
    "custom": {
        "repository": "pip-research",
        "products": {
            "baseline-enhanced": ("ResearchBaselineEnhanced", "Research Baseline Enhanced", "uk.pipreps.research.baseline.enhanced", "0.2.1"),
            "pip": ("PipResearch", "Pip Research", "uk.pipreps.research", "0.1.2"),
            "pip-enhanced": ("PipResearchEnhanced", "Pip Research Enhanced", "uk.pipreps.research.enhanced", "0.2.1"),
        },
    },
    "replica": {
        "repository": "pip-research-replica",
        "products": {
            "baseline": ("ResearchBaseline", "Research Baseline", "uk.pipreps.research.baseline", "0.1.2"),
        },
    },
}
REQUIRED = {
    "Package.swift", "LICENSE", "NOTICES.md", "README.md", "SECURITY.md",
    "CONTRIBUTING.md", "CHANGELOG.md", "TESTING.md", "PARITY.md",
    "docs/AI-SETUP.md", "docs/EDITION-MATRIX.md", "docs/TWO-REPOSITORIES.md",
    "scripts/build.sh", "scripts/package.sh", "scripts/verify-public.py",
    "DISTRIBUTION.json", "SHARED-CORE-SHA256.json", "EXPORT-SHA256.json",
}
PRIVATE_NAMES = {
    "AGENTS.md", "CONTEXT.md", "PLAN.md", "BUILD-PROMPT.md",
}
GENERATED_ROOTS = {".git", ".build", ".swiftpm", "dist"}


def export_paths(root: Path):
    """Yield export payload paths, excluding only known generated checkout/build trees."""
    for path in root.rglob("*"):
        relative = path.relative_to(root)
        if relative.parts[0] in GENERATED_ROOTS or "__pycache__" in relative.parts:
            continue
        yield path


FORBIDDEN_PATTERNS = (
    re.compile(r"/(?:Users|home)/[^/]+(?:/|$)"),
    re.compile(r"\.local-evidence[/\\]"),
    re.compile(r"\.codex[/\\]worktrees(?:[/\\]|$)"),
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    raise SystemExit(message)


def verify(root: Path, expected_profile: str | None = None) -> None:
    root = root.resolve()
    distribution_path = root / "DISTRIBUTION.json"
    if not distribution_path.is_file():
        fail("Missing DISTRIBUTION.json")
    distribution = json.loads(distribution_path.read_text(encoding="utf-8"))
    profile_name = distribution.get("profile")
    if profile_name not in PROFILES:
        fail("Unknown distribution profile")
    if expected_profile is not None and profile_name != expected_profile:
        fail(f"Profile mismatch: expected {expected_profile}, found {profile_name}")
    profile = PROFILES[profile_name]
    if distribution.get("repository") != profile["repository"]:
        fail("Repository identity does not match the profile")
    expected_products = [
        {
            "alias": alias,
            "product": data[0],
            "display": data[1],
            "bundle": data[2],
            "version": data[3],
        }
        for alias, data in profile["products"].items()
    ]
    if distribution.get("products") != expected_products:
        fail("Product metadata does not match the profile allowlist")

    for name in REQUIRED:
        if not (root / name).is_file():
            fail(f"Missing required public file: {name}")
    for path in export_paths(root):
        relative = path.relative_to(root)
        if path.is_symlink():
            fail(f"Unexpected symlink: {relative}")
        if path.is_file() and path.name in PRIVATE_NAMES:
            fail(f"Private file present: {relative}")
        if path.is_file() and path.suffix.lower() not in {
            ".swift", ".md", ".yml", ".yaml", ".json", ".sh", ".txt",
            ".png", ".jpg", ".jpeg", ".icns", ".py",
        } and path.name not in {"LICENSE", ".gitignore"}:
            fail(f"Unreviewed file type: {relative}")

    source_top = {path.name for path in (root / "Sources").iterdir() if path.is_dir()}
    owned_targets = {data[0] for data in profile["products"].values()}
    expected_source_top = {"ResearchCore", "ResearchDesktop"} | owned_targets
    if source_top != expected_source_top:
        fail(f"Executable source directories do not match profile: {sorted(source_top)}")

    package_text = (root / "Package.swift").read_text(encoding="utf-8")
    actual_products = re.findall(r'\.executable\(name:\s*"([^"]+)"', package_text)
    actual_targets = re.findall(r'\.executableTarget\(name:\s*"([^"]+)"', package_text)
    expected_names = [data[0] for data in profile["products"].values()]
    if actual_products != expected_names or actual_targets != expected_names:
        fail("Package.swift executable products/targets do not match the profile")
    for product in expected_names:
        if not (root / "Sources" / product / "main.swift").is_file():
            fail(f"Missing owned executable entry point: {product}")
    build_text = (root / "scripts" / "build.sh").read_text(encoding="utf-8")
    package_script_text = (root / "scripts" / "package.sh").read_text(encoding="utf-8")
    strip_step = 'xcrun strip -S -x "$output/Contents/MacOS/$product"'
    sign_step = 'codesign --force --sign - "$output"'
    if strip_step not in package_script_text or sign_step not in package_script_text or package_script_text.index(strip_step) > package_script_text.index(sign_step):
        fail("Package script must strip private debug information before ad-hoc signing")
    build_cases = re.findall(r"^  ([a-z0-9-]+)\) product=([A-Za-z0-9]+) ;;$", build_text, re.M)
    package_cases = re.findall(
        r"^  ([a-z0-9-]+)\) product=([A-Za-z0-9]+); display='([^']+)'; identifier=([^;]+); version=([^ ]+) ;;$",
        package_script_text,
        re.M,
    )
    expected_cases = [
        (alias, data[0], data[1], data[2], data[3])
        for alias, data in profile["products"].items()
    ]
    if build_cases != [(row[0], row[1]) for row in expected_cases]:
        fail("Build script accepts products outside the profile or uses different aliases")
    if package_cases != expected_cases:
        fail("Package script metadata does not match the distribution profile")
    if set(actual_products) != owned_targets or set(actual_targets) != owned_targets:
        fail("Package.swift contains an unowned executable target")
    if "ResearchBaseline" not in owned_targets and "Sources/ResearchBaseline/main.swift" in {
        str(path.relative_to(root)) for path in root.rglob("*.swift")
    }:
        fail("Neutral Core entry point is not permitted in the custom profile")
    if profile_name == "replica":
        if (root / "docs" / "images").exists():
            fail("Neutral replica profile must not include Pip screenshots")
        readme = (root / "README.md").read_text(encoding="utf-8")
        if "Pip Research Enhanced" in readme or "docs/images/" in readme:
            fail("Neutral replica README includes Pip branding or screenshots")

    build_commands = re.findall(r"^\./scripts/build\.sh ([a-z0-9-]+)$", (root / "README.md").read_text(encoding="utf-8"), re.M)
    setup_text = (root / "docs" / "AI-SETUP.md").read_text(encoding="utf-8")
    setup_commands = re.findall(r"^\./scripts/build\.sh ([a-z0-9-]+)$", setup_text, re.M)
    expected_aliases = list(profile["products"])
    if build_commands != expected_aliases or setup_commands != expected_aliases:
        fail("README and AI setup build commands do not match the profile")
    workflow = (root / ".github" / "workflows" / "verify.yml").read_text(encoding="utf-8")
    workflow_products = re.findall(r"swift build -c release --product ([A-Za-z0-9]+) --jobs 2", workflow)
    if workflow_products != expected_names:
        fail("CI product list does not match the profile")

    shared_path = root / "SHARED-CORE-SHA256.json"
    shared = json.loads(shared_path.read_text(encoding="utf-8"))
    actual_shared = {
        str(path.relative_to(root)): digest(path)
        for path in sorted((root / "Sources" / "ResearchCore").rglob("*"))
        if path.is_file()
    }
    if shared.get("files") != actual_shared:
        fail("Shared core hash manifest does not match ResearchCore")
    if distribution.get("sharedCoreManifestSHA256") != digest(shared_path):
        fail("Distribution shared-core manifest hash is incorrect")

    export_path = root / "EXPORT-SHA256.json"
    export_manifest = json.loads(export_path.read_text(encoding="utf-8"))
    actual_inventory = {
        str(path.relative_to(root)): digest(path)
        for path in sorted(export_paths(root))
        if path.is_file() and path.name != "EXPORT-SHA256.json"
    }
    if export_manifest.get("profile") != profile_name or export_manifest.get("files") != actual_inventory:
        fail("Export SHA-256 manifest is incomplete or stale")

    text_suffixes = {".swift", ".md", ".yml", ".yaml", ".json", ".sh", ".txt", ".py"}
    for path in export_paths(root):
        if not path.is_file() or path.suffix.lower() not in text_suffixes:
            continue
        text = path.read_text(encoding="utf-8")
        if any(pattern.search(text) for pattern in FORBIDDEN_PATTERNS):
            fail(f"Private marker found in {path.relative_to(root)}")

        if path.suffix.lower() != ".md":
            continue
        for target in re.findall(r"\]\(([^)]+)\)", text):
            if target.startswith(("https://", "http://", "mailto:", "#")):
                continue
            local = target.split("#", 1)[0]
            if local and not (path.parent / local).resolve().is_file():
                fail(f"Broken local link in {path.relative_to(root)}: {target}")

    if profile_name == "custom":
        if not (root / "docs" / "images").is_dir():
            fail("Custom profile should include its reviewed Pip screenshots")
    print(f"Public source boundary checks passed for {profile_name}; build/runtime acceptance is separate.")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=sorted(PROFILES))
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    verify(args.root, args.profile)


if __name__ == "__main__":
    main()
