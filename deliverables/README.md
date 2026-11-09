# Liefer-ZIPs

Vollständige, Godot-importierbare Projektstände (`project.godot` liegt jeweils im ZIP-Root, `.godot/` ist ausgeschlossen). Jede ZIP enthält Quellen, Assets, `.import`/`.uid`, Tests, Berichte und Screenshots des jeweiligen Stands.

| Datei | Stand |
|---|---|
| `waldspiel-PHASE2.zip` | PHASE 2 |
| `waldspiel-PHASE3.zip` | PHASE 3 |
| `waldspiel-REVISION1.zip` | REVISION 1 |
| `waldspiel-REVISION2.zip` | REVISION 2 |
| `waldspiel-REVISION3.zip` | REVISION 3 |
| `waldspiel-REVISION4.zip` | REVISION 4 |
| `waldspiel-PHASE4.zip` | **PHASE 4 — aktueller Stand** |

Der **aktuelle, lauffähige Projektstand** liegt direkt im Repo-Root (`project.godot`, `src/`, `Main.tscn`). Die ZIPs sind nur eingefrorene Pakete früherer Stände; zum Arbeiten/Godot-Importieren immer den Repo-Root bzw. die neueste ZIP nehmen.

`python3 tools/build_zip.py <PHASE>` erzeugt eine neue ZIP direkt in `deliverables/`; `.zip`-Dateien werden dabei bewusst nicht erneut eingepackt.
