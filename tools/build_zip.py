#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Baut am ENDE JEDER PHASE eine vollstaendige, in Godot importierbare ZIP.

    python3 tools/build_zip.py PHASE2

Ziel: deliverables/waldspiel-<PHASE>.zip (im Projektordner)
`project.godot` liegt im ZIP-Root (nicht in einem Unterordner), damit Godot
"Importieren -> project.godot" direkt funktioniert. Editor-Cache (.godot),
uebersetzte .translation-Dateien und Python-Caches werden bewusst
ausgelassen; alle Quellen, Assets, .import/.uid, Tests, Berichte und
Screenshots sind enthalten.
"""
from __future__ import annotations

import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PHASE = sys.argv[1].strip() if len(sys.argv) > 1 else "PHASE2"
OUT = ROOT / "deliverables" / f"waldspiel-{PHASE}.zip"

SKIP_DIRS = {".godot", "__pycache__", ".git", ".cache", ".venv", "node_modules"}
SKIP_SUFFIXES = {".translation", ".zip", ".pyc", ".log", ".tmp"}
SKIP_NAMES = {".DS_Store", "Thumbs.db"}


def wanted(path: Path) -> bool:
    rel = path.relative_to(ROOT)
    if any(part in SKIP_DIRS for part in rel.parts):
        return False
    if path.name in SKIP_NAMES or path.suffix in SKIP_SUFFIXES:
        return False
    return path.is_file()


def main() -> None:
    files = sorted(p for p in ROOT.rglob("*") if wanted(p))
    if not any(p.relative_to(ROOT).as_posix() == "project.godot" for p in files):
        raise SystemExit("FEHLER: project.godot fehlt im Projekt-Root.")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        OUT.unlink()
    with zipfile.ZipFile(OUT, "w", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=9) as z:
        for path in files:
            z.write(path, path.relative_to(ROOT).as_posix())

    with zipfile.ZipFile(OUT) as z:
        names = z.namelist()
        assert "project.godot" in names, "project.godot muss im ZIP-Root liegen"
        assert "src/Main.tscn" in names
        assert not any(n.startswith(".godot/") for n in names)
        bad = z.testzip()
        assert bad is None, f"beschaedigter Eintrag: {bad}"

    print(f"[ZIP] {OUT} | {len(files)} Dateien | {OUT.stat().st_size / 1024 / 1024:.2f} MiB")
    print(f"[ZIP] project.godot im Root: OK | CRC-Test: OK | .godot ausgeschlossen: OK")


if __name__ == "__main__":
    main()
