#!/usr/bin/env python3
"""Rasterize every SVG in assets/concept and assets/marketing to PNG using headless Chromium.

Requires: pip install playwright && playwright install chromium
Run:      python3 tools/svg_to_png.py
"""
import glob
import os
import re

from playwright.sync_api import sync_playwright

ROOT = os.path.join(os.path.dirname(__file__), "..")
DIRS = ["assets/concept", "assets/marketing"]


def main():
    files = []
    for d in DIRS:
        files += sorted(glob.glob(os.path.join(ROOT, d, "*.svg")))
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        for f in files:
            src = open(f).read()
            m = re.search(r"width='(\d+)' height='(\d+)'", src)
            w, h = int(m.group(1)), int(m.group(2))
            page.set_viewport_size({"width": w, "height": h})
            page.set_content(f"<html><body style='margin:0;background:transparent'>{src}</body></html>")
            page.wait_for_timeout(50)
            out = f[:-4] + ".png"
            page.screenshot(path=out, omit_background=True, clip={"x": 0, "y": 0, "width": w, "height": h})
            print("png", os.path.relpath(out, ROOT))
        browser.close()


if __name__ == "__main__":
    main()
