#!/usr/bin/env python3
"""Post-process the Godot Web export.

Godot's default shell is a bare canvas. This adds the Little Joy account layer,
the full-bleed phone framing, the game's title and the mobile viewport.

    python3 Tools/patch_web.py
"""

from __future__ import annotations

import pathlib
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLAY = ROOT / "web" / "play"
CLIENT = ROOT / "web" / "arcade-client.js"
MANIFEST = ROOT / "web" / "manifest.webmanifest"
FRAME = ROOT / "web" / "frame.css"
BRIDGE = ROOT / "web" / "arcade-bridge.js"

HEAD_INJECT = """\t<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover" />
\t<meta name="theme-color" content="#263b52" />
\t<meta name="apple-mobile-web-app-capable" content="yes" />
\t<meta name="mobile-web-app-capable" content="yes" />
\t<meta name="description" content="Doodle Rescue 3D — draw real 3D beams, shelters and bridges to save Biscuit. A Little Joy Arcade original." />
\t<link rel="stylesheet" href="./frame.css" />
\t<link rel="manifest" href="./manifest.webmanifest" />
\t<script src="./arcade-bridge.js"></script>
\t<script src="./arcade-client.js" data-game-id="doodle-rescue-3d"></script>
"""


def main() -> int:
    index = PLAY / "index.html"
    if not index.exists():
        print("web/play/index.html is missing — run the Godot Web export first.")
        return 1

    html = index.read_text(encoding="utf-8")
    html = re.sub(r"<title>.*?</title>", "<title>Doodle Rescue 3D</title>", html, flags=re.S)
    html = re.sub(r'\s*<meta name="viewport"[^>]*>', "", html)
    if "arcade-bridge.js" not in html:
        html = html.replace("</head>", HEAD_INJECT + "</head>")
    index.write_text(html, encoding="utf-8")

    for source, target in [(BRIDGE, PLAY / "arcade-bridge.js"),
                           (FRAME, PLAY / "frame.css"),
                           (MANIFEST, PLAY / "manifest.webmanifest")]:
        if source.exists():
            shutil.copyfile(source, target)
        else:
            print("warning: missing", source)

    if CLIENT.exists():
        shutil.copyfile(CLIENT, PLAY / "arcade-client.js")
        text = CLIENT.read_text(encoding="utf-8")
        if "__LJA_ANON_KEY__" in text:
            print("warning: arcade-client.js still has the anon-key placeholder")
    else:
        print("warning: arcade client not found at", CLIENT)

    (PLAY / ".nojekyll").write_text("", encoding="utf-8")
    # The export directory lives inside the Godot project. Without this marker
    # the editor imports the build's PNGs into the next .pck.
    (PLAY / ".gdignore").write_text("", encoding="utf-8")

    if "arcade-client.js\" data-game-id=\"doodle-rescue-3d\"" not in html:
        print("error: the account layer was not injected")
        return 2
    print("patched", index.relative_to(ROOT))
    for path in sorted(PLAY.iterdir()):
        print(f"  {path.name:32s} {path.stat().st_size / 1024 / 1024:6.2f} MiB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
