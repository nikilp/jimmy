#!/usr/bin/env python3

from __future__ import annotations

import os
import shutil
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = REPO_ROOT / "site"
DIST_DIR = REPO_ROOT / "dist"
SITE_URL = os.environ.get("SITE_URL", "https://jimmy.outfinity.net").rstrip("/")


def copy_source() -> None:
    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)
    shutil.copytree(SOURCE_DIR, DIST_DIR)


def route_for(path: Path) -> str:
    relative = path.relative_to(DIST_DIR)
    if relative.name == "index.html":
        parts = relative.parts[:-1]
        if not parts:
            return "/"
        return "/" + "/".join(parts) + "/"
    return "/" + "/".join(relative.parts)


def write_robots() -> None:
    robots = "\n".join(
        [
            "User-agent: *",
            "Allow: /",
            f"Sitemap: {SITE_URL}/sitemap.xml",
            "",
        ]
    )
    (DIST_DIR / "robots.txt").write_text(robots, encoding="utf-8")


def write_sitemap() -> None:
    pages = sorted(DIST_DIR.rglob("*.html"))
    urls = []
    for page in pages:
        route = route_for(page)
        if route == "/healthz/":
            continue
        urls.append(f"  <url><loc>{SITE_URL}{route}</loc></url>")
    sitemap = "\n".join(
        [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
            *urls,
            "</urlset>",
            "",
        ]
    )
    (DIST_DIR / "sitemap.xml").write_text(sitemap, encoding="utf-8")


def main() -> None:
    copy_source()
    write_robots()
    write_sitemap()
    print(f"Built site into {DIST_DIR}")


if __name__ == "__main__":
    main()
