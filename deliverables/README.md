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
| `waldspiel-REVISION5.zip` | REVISION 5 (vor REVISION 6) |
| `waldspiel-REVISION6.zip` | REVISION 6 (auf GitHub, `bcbd1ba`) |
| `waldspiel-REVISION7.zip` | REVISION 7 (auf GitHub, `50979d5`) |
| `waldspiel-REVISION8.zip` | REVISION 8 — vorheriger Stand, auf GitHub |
| `waldspiel-PHASE8-FIX.zip` | **KORREKTURRUNDE P8.1 — aktueller Stand, auf GitHub** |
| `waldspiel-PHASE8.zip` | PHASE 8 — fünfte Tierart (historisch) |
| `waldspiel-PHASE7.zip` | PHASE 7 — drei Biome (historisch) |
| `waldspiel-PHASE6.zip` | PHASE 6 — Bodenchemie, Mykorrhiza, Katastrophen (historisch) |

Der **aktuelle, lauffähige Projektstand** liegt direkt im Repo-Root (`project.godot`, `src/`, `Main.tscn`). Die ZIPs sind nur eingefrorene Pakete früherer Stände; zum Arbeiten/Godot-Importieren immer den Repo-Root bzw. die neueste ZIP nehmen.

`python3 tools/build_zip.py <PHASE>` erzeugt eine neue ZIP direkt in `deliverables/`; `.zip`-Dateien werden dabei bewusst nicht erneut eingepackt. Die P4-Fixrunde, PHASE 5 und REVISION 5 liegen als eigene Pakete vor, damit alle vorherigen Stände erhalten bleiben.

**REVISION 8.** Die Korrekturrunde (siehe `REVISION8-ERGEBNIS.html` / `.md`) ist als `waldspiel-REVISION8.zip` eingefroren und auf `main` gepusht (Nachfolger von `50979d5`). Sie bleibt als vorheriger Stand erhalten.

**KORREKTURRUNDE P8.1.** Der aktuelle Stand (siehe `PHASE8-FIX-ERGEBNIS.html` / `.md`) ist als `waldspiel-PHASE8-FIX.zip` eingefroren und zusammen mit dem gesamten Quellstand auf `main` gepusht (Nachfolger von `a144657`). Neun gemeldete Fehler behoben: Eichhoernchen kleiner/bodengebunden/kletternd, Specht-Flug mit Frames und Sitzplatz, verstreute Eicheln mit 20% Keimung, Toast-Stack, keine Biom-/WASD-Ruckler, nahtlose Chunkgrenzen. Alle aelteren Regressionen bleiben gruen.

**PHASE 8.** Der aktuelle Meilenstein (siehe `PHASE8-ERGEBNIS.html` / `.md`) ist als `waldspiel-PHASE8.zip` eingefroren und zusammen mit dem gesamten Quellstand auf `main` gepusht (Nachfolger von `0b2f064`). Dieses Paket ist historisch erhalten.

**PHASE 7.** Der aktuelle Meilenstein (siehe `PHASE7-ERGEBNIS.html` / `.md`) ist als `waldspiel-PHASE7.zip` eingefroren und zusammen mit dem gesamten Quellstand auf `main` gepusht (Nachfolger von `d0c719c`). Dieses Paket ist historisch erhalten.

**PHASE 6.** Der neue Meilenstein (siehe `PHASE6-ERGEBNIS.html` / `.md`) ist als `waldspiel-PHASE6.zip` eingefroren und zusammen mit dem gesamten Quellstand auf `main` gepusht (Nachfolger von `3de6561`). Dieses Paket ist historisch erhalten. Alle aelteren ZIPs bleiben ebenfalls erhalten.
