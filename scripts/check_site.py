#!/usr/bin/env python3

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import urlsplit


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ROOT = REPO_ROOT / "dist"
FORBIDDEN_SNIPPETS = [
    "https://bgdelivery.com.au/wp-content",
    "preview",
    "draft",
]
REFERENCE_RE = re.compile(r"""(?:href|src)=["']([^"'#]+(?:#[^"']*)?)["']""")


def resolve_local_reference(site_root: Path, page: Path, ref: str) -> Path | None:
    parsed = urlsplit(ref)
    if parsed.scheme or ref.startswith("//"):
        return None
    clean_path = parsed.path
    if not clean_path:
        return None
    if clean_path.startswith("/"):
        candidate = site_root / clean_path.lstrip("/")
    else:
        candidate = page.parent / clean_path
    if clean_path.endswith("/"):
        candidate = candidate / "index.html"
    return candidate


def main() -> int:
    site_root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_ROOT.resolve()
    failures: list[str] = []

    for path in sorted(site_root.rglob("*")):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        lower = text.lower()

        for snippet in FORBIDDEN_SNIPPETS:
            if snippet in lower:
                failures.append(f"{path}: contains forbidden snippet '{snippet}'")

        if path.suffix != ".html":
            continue

        for match in REFERENCE_RE.finditer(text):
            ref = match.group(1)
            if ref.startswith(("mailto:", "tel:", "data:")):
                continue
            target = resolve_local_reference(site_root, path, ref)
            if target is None:
                continue
            if not target.exists():
                failures.append(f"{path}: missing local reference {ref}")

    if failures:
        print("Site validation failed:", file=sys.stderr)
        for failure in failures:
            print(f" - {failure}", file=sys.stderr)
        return 1

    print(f"Validated {site_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
