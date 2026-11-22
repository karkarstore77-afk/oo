"""Generate hashes for imported game assets before packaging a release."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="RoofGroove", help="Godot project directory")
    args = parser.parse_args()
    project = Path(args.project).resolve()
    imported_root = project / ".godot" / "imported"
    if not imported_root.is_dir():
        raise SystemExit("Godot import cache is missing; run Godot --import first")

    entries: dict[str, str] = {}
    for import_file in project.rglob("*.import"):
        if ".godot" in import_file.parts:
            continue
        match = re.search(r'^path="res://(\.godot/imported/[^\"]+)"', import_file.read_text(encoding="utf-8"), re.MULTILINE)
        if not match:
            continue
        resource_path = "res://" + match.group(1)
        disk_path = project.joinpath(*match.group(1).split("/"))
        if disk_path.is_file():
            entries[resource_path] = hashlib.sha256(disk_path.read_bytes()).hexdigest()

    if not entries:
        raise SystemExit("No imported resources found; import the Godot project first")
    manifest = {"version": 1, "files": [{"path": path, "sha256": digest} for path, digest in sorted(entries.items())]}
    target = project / "integrity_manifest.json"
    target.write_text(json.dumps(manifest, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {len(entries)} imported-resource hashes to {target}")


if __name__ == "__main__":
    main()
