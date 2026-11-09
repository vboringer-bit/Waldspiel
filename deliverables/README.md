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
| `waldspiel-PHASE4.zip` | PHASE 4 (vor der Fixrunde) |
| `waldspiel-PHASE4-FIX.zip` | PHASE 4 + Fixrunde |
| `waldspiel-PHASE5.zip` | PHASE 5 (vor REVISION 5) |
| `waldspiel-REVISION5.zip` | **REVISION 5 — aktueller Stand** |

Der **aktuelle, lauffähige Projektstand** liegt direkt im Repo-Root (`project.godot`, `src/`, `Main.tscn`). Die ZIPs sind nur eingefrorene Pakete früherer Stände; zum Arbeiten/Godot-Importieren immer den Repo-Root bzw. die neueste ZIP nehmen.

`python3 tools/build_zip.py <PHASE>` erzeugt eine neue ZIP direkt in `deliverables/`; `.zip`-Dateien werden dabei bewusst nicht erneut eingepackt. Die P4-Fixrunde, PHASE 5 und REVISION 5 liegen als eigene Pakete vor, damit alle vorherigen Stände erhalten bleiben.
