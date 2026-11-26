#!/usr/bin/env python3
"""Build a Roof Groove content patch (.pck) with ONLY the changed files, plus the Firebase fields to set.

Usage (needs the Godot 4.7 editor binary):
  python3 tools/make_patch.py --godot /path/to/Godot --version 1.1.8 --base-build 21 \
      scripts/player.gd scripts/world_generator.gd sprites/new_skin.png ...
  (use the .import-ed asset path as it is in the project; for images/audio also include the matching .import file)
Then upload the .pck anywhere with a direct link (GitHub Release asset works) and in Firebase, document app/latest, set:
  version = 1.1.8        pck_url = <direct link>        pck_sha256 = <printed below>        pck_base_build = 21
pck_base_build must equal BASE_BUILD in scripts/patch_loader.gd of the installed APK (21 for the current build).
Never put scripts/patch_loader.gd in a patch. Players on that APK then download only this small file, no APK install.
"""
import argparse, hashlib, os, subprocess, sys

ap = argparse.ArgumentParser()
ap.add_argument("--godot", required=True)
ap.add_argument("--version", required=True)
ap.add_argument("--base-build", type=int, default=21)
ap.add_argument("--out", default=None)
ap.add_argument("files", nargs="+")
a = ap.parse_args()
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "RoofGroove")
if "scripts/patch_loader.gd" in a.files:
    sys.exit("scripts/patch_loader.gd must not be in a patch")
out = os.path.abspath(a.out or f"roofgroove-patch-{a.version}.pck")
r = subprocess.run([a.godot, "--headless", "--path", root, "-s", os.path.join("..", "tools", "make_patch.gd"), "--", out] + a.files, capture_output=True, text=True)
if "PACKED 0" not in r.stdout:
    sys.exit("failed:\n" + r.stdout + r.stderr)
h = hashlib.sha256(open(out, "rb").read()).hexdigest()
print(f"OK {out} ({os.path.getsize(out)} bytes)\nFirebase app/latest:\n  version={a.version}\n  pck_sha256={h}\n  pck_base_build={a.base_build}\n  pck_url=<direct download link of the .pck>")
