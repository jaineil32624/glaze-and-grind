#!/usr/bin/env python3
"""Posts a rich "new release" card to Discord.

Usage: DISCORD_WEBHOOK=... python3 discord_announce.py <tag> [note]
"""
import json
import os
import sys
import urllib.request

REPO = os.environ.get("GITHUB_REPOSITORY", "jaineil32624/glaze-and-grind")
OWNER, NAME = REPO.split("/")
PAGES = f"https://{OWNER}.github.io/{NAME}"
RAW = f"https://raw.githubusercontent.com/{REPO}/main"


def main() -> int:
    hook = os.environ.get("DISCORD_WEBHOOK", "").strip()
    if not hook:
        print("DISCORD_WEBHOOK not set; skipping announcement")
        return 0
    tag = sys.argv[1] if len(sys.argv) > 1 else "latest"
    note = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else ""
    rel = f"https://github.com/{REPO}/releases/tag/{tag}"
    dl = f"https://github.com/{REPO}/releases/download/{tag}"

    desc = note or "A new build of my donut & coffee shop tycoon game just dropped! 🍩☕"
    embed = {
        "title": f"🍩 Glaze & Grind {tag} is out!",
        "url": rel,
        "description": desc,
        "color": 0xE2B04A,
        "thumbnail": {"url": f"{RAW}/assets/marketing/app_icon_512.png"},
        "image": {"url": f"{RAW}/assets/marketing/github_social_preview.png"},
        "fields": [
            {"name": "▶️ Play now", "value": f"[Play free in your browser]({PAGES}/play/)", "inline": False},
            {"name": "📱 Android", "value": f"[GlazeAndGrind.apk]({dl}/GlazeAndGrind.apk)", "inline": True},
            {"name": "🪟 Windows", "value": f"[GlazeAndGrind.exe]({dl}/GlazeAndGrind.exe)", "inline": True},
            {"name": "🐧 Linux", "value": f"[GlazeAndGrind.x86_64]({dl}/GlazeAndGrind.x86_64)", "inline": True},
            {"name": "📝 Patch notes", "value": f"[Read the release]({rel}) · [Website]({PAGES}/)", "inline": False},
        ],
        "footer": {"text": "JaKing Studios 👑 · made in Godot 4"},
    }
    body = {"username": "Glaze & Grind", "avatar_url": f"{RAW}/assets/marketing/app_icon_512.png",
            "content": "🚨 **New game update!** 🚨", "embeds": [embed]}
    req = urllib.request.Request(hook, data=json.dumps(body).encode(), method="POST",
                                 headers={"Content-Type": "application/json", "User-Agent": "glaze-and-grind-ci"})
    with urllib.request.urlopen(req) as r:
        print("Discord responded", r.status)
    return 0


if __name__ == "__main__":
    sys.exit(main())
