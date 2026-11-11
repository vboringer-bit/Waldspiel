# DECISIONS.md — begründete Annahmen (PHASE 0 + 1 + 2)

Datum: 2026-11-05 · Engine: **Godot 4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`) · Sprache: GDScript

Der Master-Prompt sagt: *„Frage nach, wenn eine Design-Entscheidung unklar ist, aber triff sonst sinnvolle Annahmen und dokumentiere sie in DECISIONS.md.“* Es gab keine blockierende Unklarheit; alle Annahmen stehen hier. **Gebaut: PHASE 0, PHASE 1 und PHASE 2. PHASE 3 wurde nicht begonnen.** Abschnitte 1–10 = PHASE 0, 11–20 = PHASE 1, 21–31 = PHASE 2.

---

## 1. Phasengrenze (wichtigste Entscheidung)

PHASE 0 = *„Leeres Projekt, Ordnerstruktur, Platzhalter-Pixel, Kamera mit Zoom/Pan, ChunkManager der unebenen Boden generiert (Hügel, 1 Biom, Fels unten).“*

> **Hinweis (Stand PHASE 1):** Abschnitte 1–10 beschreiben den Stand *nach PHASE 0*. Die dort als „noch nicht enthalten" aufgezählten Punkte sind inzwischen teilweise durch PHASE 1 ergänzt – siehe Abschnitt 13.

**Enthalten:** `project.godot`, komplette Ordnerstruktur, 15 selbst generierte Platzhalter-PNGs, Kamera (Zoom/Pan), `WorldGenerator`, `ChunkManager`, `TerrainChunk`, `TerrainAtlas`, Himmel + Berg-Silhouette, verkohlte Stümpfe/Äste als **reine Deko**, Info-Overlay, Headless-Smoke-Test, DE/EN-CSV-Infrastruktur.

**Bewusst NICHT enthalten** (strikte Phasentreue): 2 Eicheln/Inventar, Vogel-Event, Keimung, Glucose/Wasser, Regen, Auto/Manuell, manuelles Wurzelwachstum, Wasserreservoirs, Höhlen, Jahreszeiten, Schwierigkeitsgrade, Skilltree, Tiere, Pilze, Parasiten, Speichern/Laden-Button, finales HUD, Ambient-Sound.

Die verkohlten Stümpfe (16×32 = 2 Tiles) und die Berg-Silhouette sind **nur Grafik** (Punkt 2 „Szenario Start“ / „nur als Silhouette, keine Kollision“), also Setup und keine Spielmechanik. Es gibt keine lebenden Bäume.

## 2. Raster & Geometrie

| Entscheidung | Wert | Grund |
|---|---|---|
| Pixelgröße | `16x16` = 1 Tile | Punkt 2, nicht verhandelbar |
| Chunkbreite | `2048 px` = `128 Tiles` | Punkt 3.1 |
| Tiefe | `68 Tiles` ≈ `1088 px` ≈ 1 Bildschirm | Punkt 3.1 |
| Mittlere Oberfläche | Welt-Y `320` | genug Himmel über dem Boden bei 1920×1080 |
| Fels-Basement | globaler Tile-Y `88` (Welt-Y `1408`), fest | „Tiefer geht es nicht“; verhindert ausgefranste Unterkante bei Hügeln |
| Höhenlinie | `FastNoiseLite` (Simplex Smooth + Detail), auf 16 px gesnappt | Hügel + Pixel-Perfektion |
| Schichtgrenzen | Tile 0 = Asche (0–16 px), Tile 1 = Humus (16–32 px), Tiles 2–12 = Mutterboden (32–208 px), Tiles 13–37 = Lehm (208–608 px), ab Tile 38 = Fels (ab 608 px) | Die 20/200/600-px-Angaben aus Punkt 3.1 auf das 16er-Raster gerundet. Abweichung ≤ 1 Tile, dokumentiert statt „krumme“ Pixel. |

Tiefe wird **relativ zur lokalen Oberfläche** gemessen: ein Hügel verschiebt alle Schichten mit. Steinklumpen werden bereits noise-basiert eingestreut (Punkt 3.1). Wasserreservoirs, Lufttaschen/Höhlen und Mykorrhiza-Pixel sind als Atlas-Slots 11/12/14/15 sowie `Material.WATER/CAVE` **vorbereitet, aber nicht generiert** (PHASE 2/5).

## 3. Biome

PHASE 0 liefert exakt **1 Biom (temperiert)**. `biome_at()`, `biome_moisture_at()` und `biome_noise_at()` sind bereits vorhanden; `biome_moisture_at()` gibt konstant `0.5` zurück. Die Smoothstep-Blende über 2–3 Chunks (links trocken / rechts feucht) folgt in PHASE 3, damit PHASE 0 nicht halb implementierte Biome zeigt.

## 4. Kollision & TileSet

`TileSet` wird zur Laufzeit aus `soil_atlas.png` gebaut (`TileSetAtlasSource`, Physics Layer 0, 16×16-Polygon pro Tile). Pro Slot existieren 3 Alternative Tiles (gespiegelt / leicht abgedunkelt), damit das 16er-Raster nicht als sichtbares Muster repetiert; die Asche-Oberfläche bleibt ungespiegelt, damit die verbrannte Kante oben bleibt. Grund: keine fragile `.tres`-Datei mit Sub-Resource-IDs; der Atlas bleibt direkt austauschbar. In PHASE 0 gibt es **keinen physics body**, der die Kollision abfragt — die Kollisionsschicht ist Vorbereitung für Wurzel-/Samen-Physik in PHASE 2 und wird dort gegen echte Bodies getestet.

## 5. Texturen & Import

- Alle Grafiken stammen aus `tools/generate_placeholders.py` (Pillow, nur Generierungszeit — das Spiel braucht kein Python). **Keine Fremd-Assets.**
- Global: `rendering/textures/canvas_textures/default_texture_filter=0` (**Nearest**), `default_texture_repeat=0`, `use_nearest_mipmap_filter=false`; PNG-Import-Dateien werden von Godot mit `mipmaps/generate=false` erzeugt.
- **Einzige Ausnahme** laut Punkt 2: Himmel-Gradient, Sonnen-Dunst und Berg-Silhouetten sind höher aufgelöst und nutzen pro Node `TEXTURE_FILTER_LINEAR`.
- `stretch/mode="canvas_items"`, `aspect="expand"`, `viewport 1920×1080`, `snap_2d_*_to_pixel=true`, `TileMapLayer.y_sort_enabled=true`.

## 6. Kamera

Mausrad → Zielzoom mit `clamp(0.5, 2.0)` und exponentiellem Lerp (smooth). WASD + Maus am Rand pannen; X unbegrenzt (infinite Chunks), Y auf `-350 … 1000` begrenzt, damit man Himmel und Fels-Basement sieht aber nicht ins Leere fährt. `teleport_to()` ist die öffentliche Schnittstelle für Save/Load, „Kamera folgt Baum“ und den Smoke-Test.

Input-Actions (`pan_left/right/up/down`) werden in `Global._ready()` per `InputMap` registriert statt in `project.godot`. Das ist robuster als handgeschriebene `InputEventKey`-Objekte in der Config und bleibt bei jedem Checkout identisch.

## 7. Hintergrund

Der Himmel ist ein bildschirmfester `CanvasLayer` (`layer=-100`) **hinter** der Welt; Boden-Tiles überdecken ihn, sobald die Kamera nach unten fährt. Berge liegen im Weltraum (`z_index=-20`) mit X-Parallax `0.18` / `0.38` und 6 nahtlos gekachelten Kopien. Beide Ebenen haben **keine Kollision** (Punkt 2: „erst später per Progression erreichbar“).

## 8. Lokalisierung

`data/localization.csv` (Key, DE, EN) wird in `Global._setup_localization()` zur Laufzeit geparst und als zwei `Translation`-Objekte am `TranslationServer` registriert; PHASE-0-Texte nutzen bereits `tr()`. Escaped `\n` in CSV-Feldern wird zu echten Zeilenumbrüchen aufgelöst. Seit PHASE 1 schaltet ein DE/EN-Button im HUD `Global.locale` um (`TranslationServer` + `EventBus.locale_changed`); ein vollwertiger Einstellungs-Dialog kann spaeter folgen.

## 9. Referenz-Repos (Stand: PHASE 1)

| Repo | Status | Verwendung |
|---|---|---|
| `GDQuest/godot-procedural-generation` | ✅ erreichbar | `make_seed_for()`-Idee → `chunk_seed()`, Sektor-Refresh um Kamera-X (`_refresh()`), nur neue Chunks erzeugen / alte freigeben. **Weiterhin aktiv.** |
| `Tdead1/GodotGeneration` | ✅ erreichbar (neu, PHASE 1) | Godot-3-Projekt (`config_version=4`), 20×20-Tile-Grid, `RandomNumberGenerator.seed`, Nachbarschafts-Smoothing und Item-Platzierung. Muster **notiert** für PHASE 2 (Höhlen-Smoothing) und einer späteren Wald-Konkurrenz. Kein Code übernommen. |
| `funferall/RHIZOMORPH` | ✅ erreichbar | Boden-Querschnitt / Substrat-Denken, CPU-Fallback + grobes Grid als Architektur-Notiz für PHASE 2/5 |
| `DrJamgo/GodotGpuConwaysLife` | ✅ erreichbar | Tile-Grid / GPU-Feld als Notiz für Wald-Konkurrenz (spätere Ausbaustufe) |
| `SeldonHh/Godot_skill_tree_maker` | ✅ erreichbar | Ressourcen-basierte Skill-Nodes als Notiz für PHASE 4 |
| `Arsenic-er/Game-Super-boring-fungi` | ✅ erreichbar | Mutations-/Upgrade-Struktur als Notiz für PHASE 4/5 |
| `marcus-zitzelsbergerit/godot-pixel-sculpt` | ❌ **404, vom Nutzer bestätigt** | **Ignoriert** (keine lokale Kopie vorhanden) |
| `marcus-zitzelsbergerit/godot-poly-sculpt` | ❌ **404, vom Nutzer bestätigt** | **Ignoriert** (keine lokale Kopie vorhanden) |

Der Nutzer hat entschieden: *„Ignoriere sie … Oder baue Chunk- und Height-Logik selbst mit FastNoiseLite (height_at(x) + ChunkManager mit 2048px Chunks) wie im Master-Prompt Punkt 3.1 beschrieben. Keine externen Addons nötig.“* Genau das ist seit PHASE 0 der Fall und bleibt so: `WorldGenerator.height_at()`, `chunk_seed()`, `ChunkManager` mit 2048px-Chunks, `TileMapLayer`. **Keine externen Addons, kein kopierter Code.**

## 10. Verifikation (PHASE 0)

Getestet mit dem echten Godot-4.7.2-Binary:

1. `godot --headless --path . --import` — Assets importieren.
2. `godot --headless --path . -- --phase0-smoke` — Determinismus, 5 Chunks, Nachladen über 5+ Chunks, Schichtfolge.
3. `godot --headless --path . --quit-after 120` — F5-Ersatz.
4. Xvfb + `--write-movie` — drei echte Screenshots (Start, Boden bis Fels, Pan auf x=4300).

`project.godot` deklariert **Forward+ / Vulkan**. Für Screenshots im Sandbox (keine GPU) wurde Xvfb mit Software-Rendering verwendet; das ändert nichts an den Projekteinstellungen.

---

# PHASE 1 — zusätzliche Entscheidungen (2026-11-05)

## 11. Zufalls-Seed (User-Antwort 1)

`Global._resolve_seed()` würfelt bei **jedem Prozessstart** `randi_range(1, 2147483646)`, nachdem der globale RNG mit `Time.get_unix_time_from_system() * 1000 + Time.get_ticks_usec()` neu geseedet wurde. Drei Teststarts ergaben drei verschiedene Seeds. „Gleiche Seed = gleiche Welt" bleibt gültig:

- `--seed=<int>` / `--phase1-seed=<int>` setzt den Seed reproduzierbar (Tests, Screenshots).
- `SaveManager` schreibt den Seed nach `user://savegame.json` und stellt ihn beim Laden wieder her (`Global.set_seed_from_save()` + `ChunkManager.set_world_seed()`).
- `Global.seed_is_random` dokumentiert im Smoke-Test, dass der Seed gewürfelt wurde.

## 12. Save/Load schon in PHASE 1

Der Master ordnet Speichern **keiner** Phase explizit zu, verlangt es aber in Punkt 9 und in den MVP-Akzeptanzkriterien („Speichern/Laden Button funktioniert"). Wegen des Zufalls-Seeds wäre dieselbe Welt nach einem Neustart sonst unerreichbar → bewusst bereits in PHASE 1 geliefert. JSON: `version, seed, auto_mode, locale, inventory, bird_event_done, trees[]` (Position + Glucose/Wasser/Health/Alter/Blätter/Wurzeln/Stamm). Runtrip wird im Smoke-Test geprüft.

## 13. Phasengrenze PHASE 1 (strikt)

**Enthalten:** 2 Eicheln, Linksklick-Platzierung, Vogel-Event (Tween-Animation), Keimling (2 Stamm-Tiles / 2 Blätter / 1 Wurzel), `Tree.gd` + `Oak.gd` + `TreeSpeciesData` (`oak.tres`), Fotosynthese, Wasser (Boden `root_count * 0.1/s`, Regen 5x), Regen-Event 120–300 s / 20–60 s mit blauen Linien, AUTO/MANUELL, HUD (Glucose+Icon, Wasserbalken, Inventar, Zeit-Platzhalter, Toggle, DE/EN, Speichern/Laden, Skilltree-Platzhalter), Rechtsklick-Info, Toast-Nachrichten.

**Bewusst NICHT enthalten** (PHASE 2+): richtungsbasiertes Wurzelwachstum, Bodenhärte/Kosten, Ghost-Preview, endliche/austrocknende Wasserreservoirs, Höhlen, L-System, art-spezifische Wurzelformen in der Simulation, Jahreszeiten/Zeitspulen, Schwierigkeitsgrade, Herbst-Eichelfall, Samen finden/vergraben, Skilltree-UI, Tiere, Pilz-Symbiose, Parasiten, Ambient-Sound.

## 14. MANUELL in PHASE 1 bewusst minimal

Der Toggle muss laut PHASE 1 „funktionieren". Deshalb: **AUTO** kauft selbst (Durst `water < 40` → Wurzel, sonst Blatt, 10 Glucose); **MANUELL** kauft per Klick (Klick unter der Oberfläche → Wurzel, darüber → Blatt, 10 Glucose). PHASE 2 ersetzt das durch Wachstum in Erd-Richtung mit Bodenhärte, Reservoir-Zielen und Ghost-Preview. Caps: 12 Blätter / 12 Wurzeln / 12 Stamm-Tiles pro Baum, max. 100 Bäume (Punkt 9).

## 15. Tutorial & Testbarkeit

1. Eichel: Vogel fliegt per Tween rein, `MSG_BIRD_EVENT` („Die Natur ist hungrig. Versuche es erneut."), Inventar 2→1, **kein** Baum. 2. Eichel: Keimung. Das echte Regen-Intervall (2–5 Min) bleibt unverändert; für Demo/Tests gibt es Taste `R`, `WaterSystem.force_rain()` und CLI-Presets. Screenshot-Presets `--phase1-shot-{bird,tree,rain}` + `--seed=` sind reproduzierbar.

## 16. Zeit / Schwierigkeit / Skilltree

`TimeManager.gd` liefert nur „Jahr 1 · Frühling" (PHASE 3). `Global.difficulty` bleibt `NORMAL`; LEICHT (0.2/s Bodenwasser, keine Katastrophen) und SCHWER (pH/N/P/K, Mykorrhiza) kommen in PHASE 3 – daher gelten die NORMAL-Werte 0.1/s und 0.35/s Verbrauch. Der Skilltree-Button ist sichtbar, aber deaktiviert (PHASE 4). **Kein Tag/Nacht-Zyklus.**

## 17. Klassennamen

`Tree.gd` hat `class_name BaseTree`, weil Godot eine native `Tree`-Control-Klasse hat (sonst Parse-Fehler „shadows a native class", analog zu `Material` → `SoilKind` in PHASE 0). `Oak.gd` nutzt `extends "res://src/plants/Tree.gd"`, also wörtlich `extends Tree` über den Pfad. `Phase0Overlay.gd` bleibt als PHASE-0-Artefakt im Repo, ist aber nicht mehr in `Main.tscn` eingehängt (ersetzt durch das echte `HUD.gd`).

## 18. Regen-Rendering

`RainEffect` ist ein `Control` unter einem `CanvasLayer`. `set_anchors_preset()` allein ergab ohne Control-Parent `size = (0,0)` → unsichtbare Linien. Fix: explizite `size` aus `get_viewport().get_visible_rect()` plus `size_changed`-Signal. 220 Linien via `_draw()`, keine Addons. Im Smoke-Test über die Gruppe `rain_effect` geprüft.

## 19. Verifikation PHASE 1

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` | Exit 0 / 0 Fehler |
| `--headless --quit-after 120` (F5-Ersatz) | Exit 0 / 0 Fehler |
| `-- --phase0-smoke` (Regression) | Exit 0 / `Ergebnis: OK` |
| `-- --phase1-smoke` (25 Checks) | Exit 0 / `Ergebnis: OK` |
| 4 Xvfb-Screenshots | 0 Fehler |
| 3 Neustarts | 3 unterschiedliche Seeds |
| DE/EN `tr()`, Regen-Partikel, Save/Load-Roundtrip | im Smoke-Test OK |

## 20. Nächster Schritt

Die PHASE 2 wurde am 2026-11-05 freigegeben und ist in den Abschnitten 21–31 dokumentiert. **PHASE 3 erst nach neuem OK.**


---

# PHASE 2 — zusätzliche Entscheidungen (2026-11-05)

## 21. Phasengrenze PHASE 2 (strikt)

Der Master-Prompt sagt: *„PHASE 2 – Wachstum & Boden: Manuelles Wachstum (klicke Wurzel -> wächst in Erd-Richtung, kostet Glucose), Boden-Typen kosten unterschiedlich, Wasserreservoirs (endlich, austrocknend), Höhlen."* Zusätzlich aus Punkt 4.2: `water_gain = 2.0 * dt` bei Reservoir-Kontakt, `capacity` nimmt ab, leer = optisch heller, und *„Zeige Ghost-Preview wohin Wurzel wachsen würde"*. Aus Punkt 4.3: Wachstum kostet abhängig von Bodenhärte (Fels teurer), Eiche = Pfahlwurzel + Herzwurzelsystem.

**Enthalten:** echte Wurzel-Segmente mit `RootTip`-Hierarchie, Klick auf Segment → Wachstum in Erd-Richtung, `GrowthCost`-Tabelle, Ghost-Preview, endliche Reservoirs mit Austrocknung + hellem Tile, Höhlen als kollisionsfreie Hohlraum-Blasen, Speichern v2 (Wurzel-Segmente + Reservoir-Zustand), HUD-Anzeige für Kosten und Reservoir-Füllstand, DE/EN-Texte.

**Bewusst NICHT enthalten** (PHASE 3+): Jahreszeiten/Zeitspulen, Herbst-Eichelfall, Samen finden/vergraben, Schwierigkeitsgrade, Buche/Kiefer, L-System-Verzweigung über der Erde, natürliche Vermehrung, Skilltree-UI (GraphEdit), Tiere, Pilz-Symbiose, Parasiten, Ambient-Sound.

## 22. Wurzel-Segmente statt Zähler

PHASE 1 kannte nur `root_count`. PHASE 2 führt `src/plants/RootSegment.gd` ein: jedes Segment hat eine `grid`-Position (Tiles relativ zum Baum), eine `direction`, einen Parent und Kinder. `BaseTree` hält `root_segments[]` und ein `_occupied`-Raster; `deepest_tip()` / `tip_for()` finden das Ende eines Astes. `MAX_ROOTS` wurde von 12 auf **32** erhöht, damit die Pfahlwurzel Reservoire in Tiefe 10–12 erreichen kann. Die PHASE-1-API (`add_root()`, `grow_part("root")`, `root_count`) bleibt erhalten – daher laufen `Phase0Smoke` und `Phase1Smoke` unverändert grün.

## 23. Art-spezifische Wurzelrichtung (Eiche)

`Oak.gd` überschreibt `root_candidates()`: die Hauptachse wächst strikt `(0,1)` (Pfahlwurzel), Ausweichziele sind diagonal; Seitenwurzeln biegen wieder nach unten. Alle `root_side_every = 4` Tiefen-Tiles erzeugt `grow_root_from()` zusätzlich eine Seitenwurzel als **weiteren anklickbaren Tip** (Herzwurzelsystem), ohne die Hauptachse zu unterbrechen. Daten stehen in `data/species/oak.tres`; Buche (Flachwurzler) und Kiefer (sehr tiefe Pfahlwurzel) kommen in PHASE 3 mit eigenen Werten/`root_candidates()`.

## 24. Boden-Kosten: 10 Glucose bleibt der Referenzwert

Das Akzeptanzkriterium *„Klick auf Wurzel -> kostet 10 Glucose"* wird als **Mutterboden = 10** interpretiert. `GrowthCost.gd` hat eine zentrale Tabelle: Asche `0.8` (8), Humus `0.9` (9), Mutterboden `1.0` (**10**), Lehm `1.3` (13), Fels `2.5` (25), Stein `3.0` (30), Reservoir `1.5` (15), Höhle `0.4` (4). Fels ist damit deutlich teurer, Hohlräume fast frei. Blatt-/Stamm-Wachstum kostet weiter den art-spezifischen Basispreis 10 (oberirdisch, keine Bodenhärte). **AUTO zahlt dieselben bodenabhängigen Kosten** wie MANUELL.

## 25. Ghost-Preview

`src/ui/GhostPreview.gd` zeigt bei Mausbewegung im MANUELL-Modus das nächste freie Erd-Tile: halbtransparentes Wurzelspitzen-Sprite, grüner Rahmen (rot bei zu wenig Glucose) und ein Label mit Bodenmaterial + Preis. `InteractionController.update_ghost()` und der tatsächliche Kauf benutzen **dieselbe** Funktion `BaseTree.propose_next_tile()` – Vorschau und Ergebnis können nicht auseinanderlaufen. Das HUD spiegelt die Werte über `EventBus.ghost_preview`.

## 26. Reservoirs: endlich, austrocknend, savebar

**Wo** ein Reservoir liegt, bestimmt allein der Seed (`WorldGenerator.reservoir_at`). **Wie voll** es noch ist, ist Laufzeit-Zustand in `src/world/WorldState.gd` (kein Autoload, vom `ChunkManager` besessen und an alle Systeme weitergereicht). Ohne diese Trennung würde ein neu geladener Chunk nach Regen/Neuimport wieder volles Wasser liefern. Kapazität 60–120 Einheiten pro Tile, Verbrauch `2.0/s` pro berührtem Wurzel-Segment. Bei 0: `EventBus.reservoir_dried` → `TerrainChunk` malt das Tile auf `SLOT_DRY_WATER` (deutlich heller) um; der Zustand bleibt über Chunk-Wechsel und Save/Load erhalten.

## 27. Höhlen

Höhlen sind dunkle `SLOT_CAVE`-Tiles ohne Kollisions-Polygon (`TerrainAtlas`), also Hohlräume im Bodenquerschnitt. Die Kosten für Wurzelwachstum sind dort am geringsten. Es gibt **keinen** Grab-/Abbau-Modus und keine begehbaren Tunnel – das wäre über den MVP-Rahmen hinaus. Sichtbare, geschlossene Höhlenkammern statt 1-Tile-Sprenkel: Ellipsen-Blasen auf einem Zellraster (siehe Abschnitt 28).

## 28. Blobs statt Noise-Sprenkel (Iterations-Entscheidung) — HISTORISCH

> **Hinweis REVISION 1:** Die hier beschriebenen gleichmäßigen 16×10-/13×9-Zellen mit je einer Ellipse wurden durch Abschnitt 35 ersetzt. Dieser Text dokumentiert nur noch den Zwischenstand.

Der erste Ansatz (`FastNoiseLite`-Threshold pro Tile) erzeugte visuell „Fernseh-Rauschen": hunderte einzelne schwarze/blaue Pixel. Deshalb jetzt deterministische Ellipsen-Blasen: pro `(Seed, Zellindex)` wird mit `hash()` entschieden, ob eine Zelle eine Blase enthält, plus Position und Radius. Höhlen: 16×10-Zellen, Radius ~4×3 Tiles, ~62 % Belegung, Tiefe 6–40. Reservoirs: 13×9-Zellen, Radius ~2.8×2, ~45 %, Tiefe 7–34. Ergebnisse werden pro Tile memoisisiert (`_cave_cache`, `_res_cache`), damit der Chunk-Aufbau nicht 1,5 Mio. Hashes pro Frame rechnet.

## 29. Garantiertes Starter-Reservoir — HISTORISCH

> **Hinweis REVISION 1:** Die feste 13-Tile-Linse wurde durch Abschnitt 35 (3×3-Kern + Noise-Linse) ersetzt.

Damit das Tutorial und die Screenshots das neue Feature **zuverlässig** zeigen, gibt es in Chunk 0 eine feste Wasserlinse: globale Tiles `x = -6 … 6`, Tiefe 10–12 relativ zur lokalen Oberfläche. Alle weiteren Reservoirs kommen aus den Blobs. Das ist eine bewusste Annahme (der Master nennt keine Verteilung); dokumentiert, seed-unabhängig und deshalb in jedem Savegame erreichbar. Die Breite von 13 Tiles toleriert die leichte Kamera-Drift durch Maus-am-Rand im Headless-Modus.

## 30. Save-Format v2 (rückwärtskompatibel)

`FORMAT_VERSION = 2`. Neu: `world_state` (`dry[]`, `remaining{}`) und pro Baum `root_segments[]` mit Grid, Richtung, Parent-Index und Tip-Flag. `BaseTree.from_dict()` akzeptiert auch alte **v1**-Spielstände ohne Segmente und baut dann aus dem bloßen `roots`-Zähler eine einfache Kette. Reihenfolge beim Laden: Seed setzen → Chunks neu bauen → `WorldState` wiederherstellen → `refresh_dry_tiles()` → Bäume rekonstruieren.

## 31. ZIP als dauerhafter Phasen-Abschluss (User-Anweisung)

Der Nutzer hat am 2026-11-05 gesagt: *„Schick mir am Ende nach Fertigstellung immer zusätzlich eine vollständige zip Datei die ich in godot einfügen kann."* Das gilt ab sofort **für jede weitere Phase**. `tools/build_zip.py <PHASE>` erzeugt `/home/user/waldspiel-<PHASE>.zip` mit `project.godot` im ZIP-Root; `.godot/`-Cache und generierte `.translation` werden ausgeschlossen, alle Quellen/Assets/Berichte/Screenshots eingeschlossen. `GODOT-IMPORT.txt` liegt im ZIP-Root und erklärt den Import. Die ZIP wird zusätzlich zum HTML-Ergebnisbericht übergeben.

## 32. Verifikation PHASE 2

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` (18 PNGs, 17 Atlas-Slots) | Exit 0 / 0 Fehler |
| `--headless --quit-after 180` (F5-Ersatz) | Exit 0 / 0 Fehler |
| `-- --phase0-smoke` (Regression) | Exit 0 / `Ergebnis: OK` |
| `-- --phase1-smoke` (Regression, 25 Checks) | Exit 0 / `Ergebnis: OK` |
| `-- --phase2-smoke` (24 Checks) | Exit 0 / `Ergebnis: OK` |
| 4 Xvfb-Screenshots (`--phase2-shot-*`) | 0 Fehler |
| ZIP-CRC-Test + `project.godot` im Root | OK |

## 33. Nächster Schritt

**PHASE 3 erst nach deinem OK:** Jahreszeiten (15–20 Min/Jahr), Zeitspulen x1/x3/x10 + Pause, Herbst-Eichelfall, Samen finden/vergraben, Schwierigkeitsgrade (LEICHT/NORMAL/SCHWER), Buche/Kiefer.

---

# REVISION 1 — vier Korrekturen vor PHASE 3 (2026-11-06)

Der Nutzer hat nach Abnahme von PHASE 2 gesagt: *„Bevor du zu PHASE 3 übergehst, mach erst folgende Dinge … und schick mir dann wieder die überarbeitete zip Datei"*. Das ist **kein** PHASE-3-Auftrag, sondern eine Korrekturrunde. PHASE 3 bleibt gesperrt.

## 34. Vollbild muss den Monitor ausfüllen

**Problem:** `window/stretch/aspect="expand"` mit `scale=1.0` vergrößerte beim Vollbild nur das *Fenster*, nicht die Spielinhalte — das Spiel blieb gleich groß, der Rest war grau.

**Lösung (zweiteilig):**
- `project.godot`: `display/window/size/mode=3` (`WINDOW_MODE_FULLSCREEN`) → F5 startet bereits im Vollbild.
- `Main._fit_display()`: `content_scale_factor = min(Fensterbreite/1920, Fensterhöhe/1080)`, bei `size_changed` neu berechnet, auf `[0.25, 4.0]` begrenzt. Zusammen mit `aspect="expand"` wird der Root-Viewport **größer** statt von Balken umgeben; alle Canvas-Inhalte werden einheitlich mitvergrößert (Pixel bleiben quadratisch).
- `F11` schaltet Fullscreen/Windowed um; `--windowed` ist ein Test-Override.

**Warum `expand` und nicht `keep`:** `keep` skaliert ebenfalls, erzeugt aber auf 21:9-Monitoren seitliche Balken. `expand` + Faktor zeigt dort mehr Welt (die Welt ist unendlich, Himmel/HUD passen sich an `get_viewport().size` an) und füllt **jedes** Format. Verifiziert mit Xvfb-Root-Screenshots bei 2560×1440 und 3440×1440: Grau-Anteil < 0,02 %, keine roten Fehler.

## 35. Organischere Höhlen / Reservoirs

**Problem:** Ein gleichmäßiges Raster (16×10 / 13×9 Zellen) mit je einer ähnlich großen Ellipse wirkte „geplant und strukturiert".

**Lösung:** `WorldGenerator._blob_field()` erzeugt pro Zelle **1–3 rotierte Ellipsen** (`cos/sin` auf `dx/dy`), Radien variieren stark, Zentren jittern über zwei Zellbreiten, und `FastNoiseLite`-Kanten verformen den Rand um ±~0,5. Drei überlagerte Familien mit verschiedenen Zellgrößen/Salts:

| Familie | Zellen | Dichte | Radius | Form |
|---|---|---|---|---|
| Große Kammern | 24×15 | 48 % | 2,5–7,0 | normal |
| Kleine Taschen | 17×11 | 26 % | 1,4–3,2 | normal |
| Lange Gänge | 31×19 | 14 % | 4,0–9,0 | ×1,85 längs / ×0,55 quer |

Reservoirs: 19×13 / 34 % / 1,6–3,6, Tiefe 7–36. **Bewusst behalten:** kohärente Blobs statt 1-Tile-Noise (sonst „Fernseh-Rauschen"), Memoisation in `_cave_cache`/`_res_cache`, deterministisch pro Seed.

**Starter-Reservoir:** nur noch ein garantierter **3×3-Kern** (`x=-1…1`, Tiefe 10–12) für Tutorial/Smoke; darum herum eine unregelmäßige Noise-Linse (`nx²+ny² ≤ 1 + noise·0,5`) bis `|x| ≤ 9`, Tiefe 8–15. Dadurch bleibt der Test reproduzierbar, aber die Form wirkt nicht mehr wie ein Rechteck.

**Verifikation:** `--rev1-smoke` prüft ≥ 3 zusammenhängende Komponenten mit ≥ 3 verschiedenen Größen, < 12 % Solitär-Tiles, > 10 % Unterschied zu einem anderen Seed und > 3 Wasser-Tiles außerhalb des Kerns.

## 36. Fließende Oberfläche ohne große Ecken

**Problem:** `height_at()` rastet auf 16 px → sichtbare 90°-Stufen an jedem Höhenwechsel.

**Lösung:** Trennung von **Darstellung** und **Logik**:
- `height_smooth_at(x)` = kontinuierliche `FastNoiseLite`-Linie (P0-Noise, unverändert, damit Seeds kompatibel bleiben).
- `TerrainSurface.gd` (neuer `Node2D`, `z_index=1`) zeichnet pro Chunk ein Profil aus 512 Stützpunkten im **4px-Raster** als `draw_colored_polygon`, plus verbrannte Oberkante, hellen Aschesaum und deterministische Sprenkel. Maximaler Sprung = 4 px.
- `Chunk._build_terrain()` lässt die **oberste TileMapLayer-Zeile weg**; das Kap deckt sie inklusive halber Höhenversätze ab (Unterkante `ty*16+24`).
- `depth_px_at()` ersetzt die starren Schichtgrenzen: Asche < 16 px, Humus < 32, Mutterboden ≤ 208, Lehm ≤ 608, sonst Fels — die Grenzen wandern jetzt sanft mit der Hügellinie.
- Bäume stehen auf `roundf(height_smooth_at(x)/4)*4`; `BaseTree.global_tile_for()` nutzt als Wurzel-Ursprung bewusst `surface_tile_y_at(x)` statt `floor(y/16)`, damit die Wurzeln bei halben Höhen nicht um ein Tile springen.
- 16px-Raster bleibt für Tiles, Kollision, Wurzel-Grid, Chunk-Grenzen und Save/Load erhalten → kein Bruch mit P0–P2.

**Z-Order:** Hintergrund −20 / TileMapLayer 0 / `TerrainSurface` 1 / Bäume 2 / Ghost 3 / Vogel 50 / HUD `CanvasLayer` 10 / getragene Eichel `CarryLayer` 9.

## 37. Eichel: aufnehmen → schweben → platzieren → Vogel

**Problem:** Ein Klick auf das Eichel-Icon fiel wegen `mouse_filter=IGNORE` durch bis `_unhandled_input()` und pflanzte sofort an der Mausposition — der Vogel kam damit schon beim „Anklicken", nicht beim Platzieren. Der Nutzer möchte: Eichel schwebt an der Maus, freie Platzierung, Vogel **erst danach**.

**Lösung:**
- HUD: `_seed_icon` ist jetzt `MOUSE_FILTER_STOP`, 28×28 px, Hand-Cursor + DE/EN-Tooltip; `gui_input` ruft `InteractionController.pick_up_acorn()` und konsumiert das Event.
- `pick_up_acorn()` zieht 1 Eichel ab, erzeugt ein 2×-Sprite auf dem neuen `CarryLayer` (`CanvasLayer`, `layer=9`) und eine halbtransparente Vorschau auf der Oberfläche. `_process()` lässt das Sprite mit `sin()` leicht schweben und folgt `get_viewport().get_mouse_position()`; die Vorschau rastet auf `snap(x,16)` × `height_smooth_at`.
- Der **nächste Linksklick** ruft `_place_carried()` → `plant_seed_at(..., already_paid=true)`. Erst hier wird `EventBus.seed_placed` gesendet und (bei der ersten Eichel) `spawn_bird()` ausgelöst. Platzierung ist an **jedes x** erlaubt, auch über Bäumen oder im Himmel; die Y wird auf die Oberfläche gesetzt.
- Abbruch: Rechtsklick oder `Esc` → `clear_carrying(true)` (Eichel zurück, kein Vogel, kein Verbrauch).
- `SaveManager` schreibt `inventory = get_seed_count() + (1 if carrying else 0)`; `load_game()` ruft `clear_carrying(false)`, damit keine Geister-Sprites bleiben. Format bleibt **v2**, alte Saves funktionieren weiter.
- Vogel-Text in `data/localization.csv` angepasst („Der Vogel hat die erste **platzierte** Eichel geholt …"); `Phase1Smoke` prüft den neuen DE/EN-Text.

**Testbarkeit:** `debug_carry_at(screen, world_x)` / `debug_place_carried_at(world_x)` und die Presets `--rev1-shot-carry`, `--rev1-shot-placed` machen den Zustand ohne echte Maus reproduzierbar. Bestehende Debug-Hooks (`debug_plant_twice`, `debug_first_seed`) bleiben für P0–P2-Smokes unangetastet.

## 38. Verifikation REVISION 1

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` | Exit 0 / 0 Fehler |
| `--headless --quit-after 180` (F5-Ersatz) | Exit 0 / 0 Fehler |
| `-- --phase0-smoke` / `--phase1-smoke` / `--phase2-smoke` | alle Exit 0 / `Ergebnis: OK` |
| `-- --rev1-smoke` (30 Checks) | Exit 0 / `Ergebnis: OK` |
| Xvfb 1920×1080: surface / carry / placed / caves | 4 Screenshots, 0 Fehler |
| Xvfb Root-Capture 2560×1440 + 3440×1440 | Vollbild füllt, Grau < 0,02 % |
| 5 Chunks nach Pan · Nearest + Forward+ · DE/EN | OK |
| ZIP-CRC + Extrakt-Import + `--rev1-smoke` aus der ZIP | OK |

## 39. Nächster Schritt (REVISION 1 — historisch)

**PHASE 3 erst nach deinem OK.** Keine Jahreszeiten, kein Zeitspulen, kein Herbst-Eichelfall, keine Schwierigkeits-UI, keine Tiere, kein Mykorrhiza-Netz. Die ZIP `waldspiel-REVISION1.zip` war der Abschluss der ersten Korrekturrunde; sie wurde inzwischen durch `waldspiel-REVISION2.zip` ersetzt (siehe Abschnitte 40–45).


---

# REVISION 2 — zweite Korrekturrunde vor PHASE 3

Ausgangslage: Der Nutzer bat vor PHASE 3 um drei weitere Änderungen: **„mach alle anderen Strukturen (Höhlen, Wasserreservoirs, Erdschichten) auch mit schöneren Kanten wie die Oberfläche"**, **„Mach Höhlen außerdem um ungefähr 50% seltener."** und **„Gib dem Wasser außerdem realistische Eigenschaften, sodass es in einem Reservoir zusammenhängt und langsam von oben nach unten abnimmt, also verbraucht wird, anstatt das nur die Zellen mit einer Wurzel austrocknen."**

## 40. Weiche Kanten für Höhlen, Wasser und Erdschichten

**Problem:** REVISION 1 hatte nur die *oberste* Geländelinie auf 4px geglättet (`TerrainSurface.gd`). Alles darunter kam weiterhin aus der 16px-TileMapLayer: Höhlen und Wasser als harte Blockstufen, Schichtgrenzen als gerade Sprünge.

**Lösung — neues `src/world/TerrainContours.gd`** (`z_index=1`, `SUB=4`, `STEPS=512`):

- `_erase_structure_tiles()` übermalt alle Höhlen-/Wasser-Tiles mit dem echten Boden-Atlas (`WorldGenerator.soil_slot_at()`), damit keine Blockecken durchscheinen. `atlas_slot_at()` wurde dafür von `soil_slot_at()` getrennt: Ersteres darf weiterhin CAVE/WATER/DRY_WATER liefern, Letzteres liefert **immer** ein Erd-Slot.
- Erdschichten: Für jede der vier Grenzen (16/32/208/608 px Tiefe) wird `layer_edge_y(world_x, depth, salt)` in 4px-Schritten abgetastet; je ein 10px-Farbverlauf nach oben/unten, eine dunkle 2px-Rim-Linie und ein 1px-Lichtsaum. Die Grenze folgt damit der Hügellinie statt einer Geraden.
- Höhlen / Wasser: Die Tile-Belegung wird als bilineares Vorzeichenfeld `f ∈ [-1,+1]` interpoliert (Smoothstep auf `fx/fy`), mit `edge_wobble_at(px,py,salt) * 0.85` überlagert; die Isolinie `f = -0.02` wird in 4px-Zellen gerastert. Ergebnis: abgerundete, leicht zerfranste Umrisse statt 16px-Stufen.
- **Chunk-Kontinuität:** `_s(gx,gy,is_water)` fragt `generator.cave_at()/reservoir_at()` mit **globalen** Tile-Koordinaten ab (dort gecacht). Ein chunk-lokales Set hätte an jedem Übergang eine Lücke erzeugt. Senkrechte Rim-Linien bei `lx<=0` / `lx>=CHUNK_W-4` werden unterdrückt, und `_erase_one()` **und** die Blob-Rasterung sind strikt auf `0 <= lx < CHUNK_W` begrenzt — sonst löscht ein Chunk das Rand-Tile des Nachbarn, zeichnet es aber nicht neu (braune Naht, in Xvfb reproduzierbar und behoben).
- `EventBus.reservoir_level_changed` löst `queue_redraw()` aus, damit der weiche Wasserspiegel bei jeder Pegeländerung mitwandert.

**Bewusst beibehalten:** Das 16px-Raster bleibt für `TileMapLayer`, Kollision, Wurzel-Grid, Chunk-Grenzen und Save/Load. Nur die *Darstellung* ist 4px — exakt dieselbe Trennung wie bei der Oberfläche in REVISION 1.

## 41. Höhlen ~50 % seltener — über Fläche, nicht über Zellenzahl

**Erster Ansatz (verworfen):** `cave_density_scale=0.5` halbierte die Anzahl der Blob-Zellen. Messung über sechs Seeds ergab Verhältnisse **0.50 / 0.28 / 0.73 / 0.63 / 0.00 / 0.59** — bei einem Seed verschwanden die Höhlen komplett, bei einem anderen blieben fast alle. Zu instabil für „ungefähr 50 %".

**Lösung:** `cave_area_scale = 0.5` lässt die ursprünglichen Blob-Zellendichten (48/26/14) **unverändert** und skaliert nur die Radien mit `_cave_radius_scale = sqrt(0.5) ≈ 0.707`. Weil die Fläche einer Ellipse quadratisch mit dem Radius wächst, halbiert das die bedeckte Fläche, ohne die seed-deterministische Verteilung anzutasten. `set_cave_area_scale()` (clamp 0.05–2.0) erlaubt Tests den direkten Vergleich mit REVISION 1 (`1.0`).

**Messung über sechs Seeds (0.5 / 1.0):** 771/1403 = **55 %**, 779/1536 = **51 %**, 572/1062 = **54 %**, 377/727 = **52 %**, 197/370 = **53 %**, 933/1750 = **53 %**. Kein 1-Tile-Rauschen, keine leeren Welten.

## 42. Wasser als zusammenhängendes Becken mit sinkendem Pegel

**Problem:** Vorher hatte jedes Reservoir-Tile einen eigenen 60–120-Vorrat; `consume()` trocknete nur das Tile mit Wurzelkontakt aus. Optisch und logisch zerfiel ein Becken in einzelne trockene Würfel.

**Lösung — `src/world/WorldState.gd` komplett neu:**

- 4-fach verbundene Wasser-Tiles werden per Flood-Fill (lazy, pro Tile gecacht, `MAX_GROUP_TILES=1200`) zu **einem Becken** mit `capacity = tiles * 90` und **einem** `volume`.
- `tiles` werden nach `y` (dann `x`) sortiert. `_recompute_level()` leitet aus dem Füllgrad `dry_count = n - ceil(fill*n)` die `level_row` ab; `_apply_dry()` markiert alle Tiles mit `y < level_row` als trocken. `waterline_px()` liefert `level_row * 16` in Welt-Pixeln. Damit sinkt der Wasserspiegel **zeilenweise von oben nach unten**.
- `consume(gx,ty,amount)` entnimmt dem **ganzen** Becken, unabhängig davon, an welchem Tile die Wurzel sitzt. `tick_passive()` versickert `0.015 * tiles * delta` sehr langsam; `refill(delta)` füllt bei Regen mit `1.2 * delta` auf.
- `remaining_at()` rechnet `generator.reservoir_capacity_at() * fill_fraction()` auf die alte Pro-Tile-Skala um, damit HUD, `WaterSystem` und der P2-Smoke unverändert funktionieren.
- `EventBus.reservoir_level_changed` benachrichtigt `Chunk` (Tile-Farben) und `TerrainContours` (weicher Pegel). `SaveManager.FORMAT_VERSION = 3` speichert `{"groups": {id: volume}, "dry": [...]}`; `from_dict()` bricht nach `groups` ab, damit alte `dry`/`remaining`-Felder ein v3-Volumen nicht auf 0 überschreiben. v2/v1-Saves bleiben lesbar (`_legacy_dry`).

**Zusammenhängend auch geometrisch:** `WorldGenerator.reservoir_at()` führt eine **1-Tile-Dilatation** durch — ein Erd-Tile mit ≥ 2 nassen direkten Nachbarn wird Wasser. Das schließt Löcher in der Linse und verbindet eng benachbarte Linsen zu einem Becken. `TerrainContours._close_water_gaps()` schließt zusätzlich kleine horizontale Lücken (≤ 8 Subzellen = 32 px) in der 4px-Rasterung. Für Lückenzellen wird der Pegel vom nächsten echten Wasser-Tile derselben Zeile geerbt, damit zwei benachbarte Becken unterschiedlich voll sein können.

**Darstellung:** Oberhalb des Pegels `DRY_FILL` (heller Leerboden), darunter `WATER_FILL` (Blau), dazwischen eine 2px-`WATER_SURFACE`-Linie. Screenshots mit 45 % und 18 % Füllstand zeigen die Wanderung.

## 43. Regressionen und Debugging-Erkenntnisse

- `TerrainContours.gd` musste `tv as Vector2i` casten (GDScript 4.7 meldete sonst untyped `sx`/`sy` und erzeugte eine Import-Kaskade).
- P2-/REV1-Smokes scannten einen zu schmalen Höhlenbereich; nach der Radius-Halbierung fanden sie zu wenige Kandidaten. Scan auf `gx -48..48`, `ty top+5..top+45` verbreitert und REV1-Varianzprüfung auf relative Differenz `different/union > 0.45` umgestellt.
- `consume()` mit 12 oder 900 Einheiten senkte bei großen Becken keine ganze Zeile → Test rechnet jetzt `needed = tiles.size() * PER_TILE_VOLUME * 0.30` und prüft `fill_fraction < 0.5`.
- v3-Save lud 35 % → 0 %, weil `from_dict()` nach den Gruppen noch die Legacy-Felder auswertete; behoben durch frühzeitiges `return`.
- Chunk-Naht: `_erase_one()` löschte Rand-Tiles des Nachbarn, ohne sie neu zu zeichnen. Beide Durchgänge jetzt hart auf den eigenen Chunk begrenzt (siehe Abschnitt 40).

## 44. Verifikation REVISION 2

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` (Godot 4.7.2 stable) | Exit 0 / 0 Fehler |
| `-- --phase0-smoke` / `--phase1-smoke` / `--phase2-smoke` | alle Exit 0 / `Ergebnis: OK` |
| `-- --rev1-smoke` (Vollbild, Oberfläche, Eichel-Fluss) | Exit 0 / `Ergebnis: OK` |
| `-- --rev2-smoke` auf 3 Seeds (26 Checks) | Exit 0 / `Ergebnis: OK`, Höhlen 55 % / 51 % / 53 %, Save 35 % → 35 % |
| Xvfb 1920×1080: edges / water / water-low / caves / surface | 5 Screenshots, je 0 Fehler |
| Xvfb Root-Capture 2560×1440 | Vollbild füllt, kein grauer Rand |
| 5 Chunks · Nearest + Forward+ · DE/EN · ZIP-CRC + Extrakt-Import | OK |

## 45. Abschluss und PHASE-3-Sperre

**PHASE 3 wurde NICHT begonnen und startet erst nach deinem ausdrücklichen OK.** Keine Jahreszeiten, kein Zeitspulen, kein Herbst-Eichelfall, keine Samen-Suche/Vergraben, keine Schwierigkeitsgrade, keine Tiere, kein Mykorrhiza-Netz.

Abschluss dieser Runde ist die **neue, vollständige ZIP `waldspiel-REVISION2.zip`** mit `project.godot` im Root, allen Quellen/Assets/`.import`/`.uid`, Tests, `REVISION2-ERGEBNIS.md/.html` und den fünf REV2-Screenshots. `.godot/` ist ausgeschlossen. Die ZIPs `waldspiel-PHASE2.zip` und `waldspiel-REVISION1.zip` sind historisch.

---

# PHASE 3 — Zeit & Reproduktion (2026-11-07)

## 46. Zwei Korrekturen VOR PHASE 3 (ausdrücklicher User-Wunsch)

**46.1 Regen füllt Reservoirs wieder auf.** Der User meldete im Spieltest, dass das nicht passierte. Ursache: `WorldState.refill()` addierte `1.2 * delta` **unabhängig von der Beckengröße** — bei 114 Tiles und 10 260 Einheiten Kapazität sind 1.2 Einheiten/s ≈ 0.01 %/s, also unsichtbar. Zudem lief das Auffüllen vor/neben `consume()`, sodass die Wurzelentnahme den Zuwachs auffressen konnte.

**Lösung:** `RAIN_REFILL_PER_TILE = 0.9`, `refill(delta, factor) = 0.9 * tiles.size() * factor * delta` — bei 114 Tiles ≈ 102.6 Einheiten/s ≈ 1 %/s. `WaterSystem.tick()` nutzt `TimeManager.scaled_delta()` (x1/x3/x10 + Pause), multipliziert mit `Global.difficulty_factor("rain_refill")` und ruft `refill()` **nach** allen Wurzel-Entnahmen auf. Pegelzeile (`waterline_px()` / `_recompute_level()`) steigt dadurch wieder sichtbar. Smoke: 20 % → 40 % in 20 s, Pegelzeile 34 → 32; nach `consume(..., 200)` und 5 s Regen 38.1 % → 43.1 %. Toast `MSG_RAIN_REFILL` + HUD „Es regnet". Regen-Partikel/Tweens bleiben bewusst in Echtzeit (visuelles Feedback, keine Spielzeit).

**46.2 Vogel fliegt aus dem Bild.** Vorher tween-te `BirdEvent` auf `at + (-780, -280)` und rief danach `queue_free()` auf — bei großem Zoom oder nach Kamera-Pan lag dieser Punkt noch **mitten im sichtbaren Bild**. Das war genau der gemeldete Effekt.

**Lösung:** Ziel wird aus Kamera und Viewport berechnet: `exit_world_x() = camera.global_position.x - viewport_width / (2 * zoom) - 240`. Einstieg `max(at.x + 700, screen_right_world_x() + 140)`. Der Sprite wird **pro Frame** mit `FLY_SPEED = 900` (skaliert mit `delta`) bewegt, `_active_flap` animiert die Flügel, und `queue_free()` passiert erst, wenn `sprite.position.x` tatsächlich hinter der linken Kante liegt. Dauer `clamp(dist / 900, 1.3, 3.4)` s. Debug-Hooks `debug_bird_progress()` / `debug_active_sprite()` / `debug_cleanup()` machen den Rand-Exit im Smoke und in zwei Xvfb-Screenshots prüfbar.

## 47. Zeitmodell: eine einzige Zeitquelle

`TimeManager` ist von einem P1-Platzhalter zum echten System geworden. Bewusste Entscheidung: **alle spielrelevanten Systeme bekommen ihre Zeit ausschließlich über `scaled_delta(delta)`**, statt überall `delta * Global.time_scale` zu streuen. `GrowthSystem`, `WaterSystem`, `SeasonSystem` und `Tree.photosynthesize()` (→ `Tree.age`) hängen daran; Regen-Partikel und UI-Tweens bleiben in Echtzeit, damit Pause/x10 die Optik nicht einfriert bzw. nicht 10× schneller zappelt.

`year_length_seconds = 900.0` (15 Echtzeit-Minuten, im zulässigen 15–20-min-Fenster), 4 Jahreszeiten à 225 s. `growth_factor()` 1.35 / 1.00 / 0.80 / 0.00 und `sunlight_factor()` 1.25 / 1.00 / 0.70 / 0.00. **Kein Tag/Nacht-Zyklus** (Master-Punkt 5, User-Wunsch). `SCALES = [1.0, 3.0, 10.0]`, Pause per Leertaste und HUD-Button; `to_dict/from_dict()` sichern Jahr, Saison,Elapsed-Zeiten, Skala und Pause.

`Tree.set_season()` setzt `growth_blocked` im Winter, entfernt die Blatt-Sprites (`is_bare()`) und tönt sie im Herbst. Zusätzlich prüft `InteractionController.manual_growth()` den Winter, damit der Spieler nicht über den Umweg „Klick" doch wachsen kann.

## 48. Samen: Noise, Hügel, Wurzel-Reichweite

`WorldGenerator.ground_seeds_for_chunk()` erzeugt pro Chunk eine seed-deterministische Kandidatenliste aus einem eigenen `_seed_noise` (getrennt vom Höhlen-/Wasser-Noise, damit Änderungen an der Dichte die Geometrie nicht verändern). `SeasonSystem` filtert sie über `density_threshold()` (Schwierigkeit) und legt Sprites in `GroundSeeds` (eigener `Node2D`, nicht Teil der Chunk-TileMaps — sonst würden Chunk-Unloads die Einsammel-Logik mitlöschen).

Vergrabene Samen liegen bei `ty = surface_tile_y_at(wx) + 2` (zwei Tiles unter der Oberfläche = *flach*, also wurzel-erreichbar, aber nicht sofort anklickbar). `_check_buried()` vergleicht alle Wurzel-Segmente aller Bäume mit allen vergrabenen Samen (Tile-Distanz ≤ 1). **Erst dann** wird `seed_found` / `seed_collected` emittiert und das Inventar erhöht. Der Smoke stellt das explizit sicher: ohne Wurzel `not debug_is_collected(bid)`, nach `debug_grow_roots(3)` `true`.

Eingesammelte IDs landen in `collected` und im Savegame v4; `chunk_unloaded` (neu in `ChunkManager.set_world_seed()`) entfernt nur die Sprites des entladenen Chunks, `chunk_loaded` erzeugt sie beim Reload ohne die gesammelten neu. Das verhindert den klassischen „Eichel-Respawn nach Weglaufen"-Bug.

## 49. Herbstfall, Reifealter und Keimung

`MATURE_AGE_YEARS = 3.0` — der Master nennt „z. B. 3 Spiel-Jahre". Ein erster Entwurf hatte `1.0` (mit der Überlegung, 45 Minuten Wartezeit bei x1 seien zu lang); das wurde **verworfen**, weil der User die Reproduktion ab ~3 Jahren erwartet und x10 das in 4.5 Minuten erreichbar macht. `maturity = clampf(age_years / 3.0, 0, 1)` geht linear in `chance = 0.55 * (0.20 + 0.80 * maturity) * difficulty_factor("acorn_chance") * (1 + spread_bonus)` ein: junge Bäume werfen also selten, alte regelmäßig ab.

Eicheln fallen per Tween unter die Krone (`±40 px`) auf `height_smooth_at()`; `_land()` prüft `sunlight_factor() > 0.4` und „nicht Winter", dann `GERMINATION_CHANCE = 0.22 * difficulty_factor("germination") * (1 + spread_bonus)`. Bei Keimung `InteractionController.spawn_tree_at()`, sonst bleibt ein einsammelbares Boden-Item liegen. `MAX_DROPS_PER_AUTUMN = 14`, `MAX_TREES = 100` (Schutz gegen unbegrenztes Wachstum bei x10). `spread_bonus` / `set_spread_bonus()` ist der reservierte Anschluss für den Skill **„Verbreitung"** — die **Skilltree-UI bleibt PHASE 4** (Master-Meilenstein).

## 50. Schwierigkeitsgrade: ein Ort, klare Grenze

Alle Modifikatoren liegen in `Global.difficulty_factor(key)` mit **NORMAL = 1.0 als Referenz** (deshalb bleiben P0/P1/P2/REV1/REV2-Smokes unverändert grün). `Global.set_difficulty(int)`, `difficulty_chosen`, `difficulty_from_name()` und `--difficulty=` ergänzen `EventBus.difficulty_changed`. `StartMenu` ist ein nicht-blockierendes `CanvasLayer` (Layer 20): es fragt vor dem Start, überschreibt aber keine laufende Sitzung; der HUD-Button zyklet jederzeit weiter. `_should_show_start_menu()` unterdrückt das Panel für alle Test-/Preset-/CLI-Argumente.

**Bewusste Grenze (Master-Punkt 4.2):** LEICHT = „keine Naturkatastrophen, kein pH", NORMAL = „seltene Stürme/Parasiten", SCHWER = „volle Simulation: pH, N/P/K, Mykorrhiza nötig, häufige Katastrophen". Diese Subsysteme existieren im MVP noch nicht; PHASE 3 legt deshalb **`difficulty_toggle()`** (LEICHT: alles aus; NORMAL: nur `disasters`/`parasites`; SCHWER: alles an) sowie die Faktoren `disaster_rate` (0.00 / 0.35 / 2.00) und `soil_complexity` (0.00 / 0.50 / 1.00) an, speichert die Wahl und prüft sie im Smoke. **Die Parasiten-/Schwierigkeits-Schalter werden in PHASE 5 erstmals echt genutzt**; die übrige pH-/N-P-K-/Mykorrhiza-/Katastrophen-Simulation bleibt einer späteren Ausbaustufe zugeordnet. Der P3-Meilenstein (Master Zeile 153) nennt ausschließlich Zeit, Eichelfall, Samen und Schwierigkeitsgrade.

## 51. Savegame v4 und Vollbild-Zusatzbefund

`FORMAT_VERSION = 4` ergänzt `difficulty`, `time` und `seeds`; `setup(..., p_time, p_season)` reicht `TimeManager` und `SeasonSystem` an `to_dict/from_dict()` durch. Ältere v3/v2/v1-Saves bekommen NORMAL / Jahr 1 / Frühling / leere Samenliste als Defaults — kein Bruch mit REVISION 2.

**Zusatzbefund beim 2560×1440-Root-Capture:** `Main._fit_display()` setzte `content_scale_factor = min(ws.x/1920, ws.y/1080) = 1.333`. Bei `canvas_items` + `expand` skaliert Godot aber **bereits selbst**; der Faktor wurde obendrauf multipliziert → sichtbarer Viewport nur **1440×810** statt 1920×1080, HUD-Elemente ab x≈1440 abgeschnitten („F11 = Voll…", „Pau…"). Das betraf schon REVISION 2, fiel dort aber hinter der „kein grauer Rand"-Prüfung nicht auf. Fix: `content_scale_factor = 1.0`. Debug-Ausgabe danach: `window=(2560,1440), visible=(1920,1080), scale=1.0`. Verifiziert bei 2560×1440 und 3440×1440; Regressionstest in `--p3-smoke`.

## 52. Verifikation PHASE 3

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` / `--quit-after 180` | je Exit 0 / 0 Fehler |
| `--phase0/1/2-smoke`, `--rev1-smoke`, `--rev2-smoke` (ohne `--seed`) | je Exit 0 / `Ergebnis: OK` |
| `--p3-smoke` | Exit 0 / **55 Checks OK** / 0 `FEHLER` |
| Xvfb 1920×1080: difficulty / spring / autumn / winter / seeds / rain-refill / bird-mid / bird-exit / rev2-edges | 9 Renders, je Exit 0 / 0 Fehler |
| Xvfb Root-Capture 2560×1440 / 3440×1440 | HUD vollständig, kein grauer Rand |
| ZIP: CRC, `project.godot` im Root, `.godot` ausgeschlossen, Extrakt-Import + 6 Smokes | OK |
| `data/localization.csv` | 76 Zeilen, `HUD_YEAR` = „Jahr"/„Year", 17 neue DE/EN-P3-Keys |
| 8 feste Seeds + 5 Zufallsläufe `--rev1-smoke` | je Exit 0 / `Ergebnis: OK` |

**Stabilisierung eines Legacy-Tests:** Beim Import der entpackten ZIP fiel `--rev1-smoke` bei einem ungünstigen Zufalls-Seed mit 2 Fehlern auf („Hoehlen (26)…", „1 Komponenten / 1 Groessen"). `Revision1Smoke.gd` scannte nur `ty = top+5..top+31`, während `Phase2Smoke.gd` und `Revision2Smoke.gd` schon auf `top+5..top+45` erweitert waren; nach der REV2-Halbierung der Höhlenfläche reichten 26 Zeilen nicht mehr für die Schwellwerte. Der Suchbereich wurde **vereinheitlicht**, keine Schwelle aufgeweicht, kein Spielcode geändert. Verifikation: 8 Seeds (1 … 271828) mit 250–579 Kacheln / 15–33 Komponenten sowie 5 Läufe ohne `--seed` mit 241–366 Kacheln, alle OK.

## 53. Abschluss PHASE 3

Geliefert werden `waldspiel-PHASE3.zip` (vollständiges Projekt, `project.godot` im Root), `PHASE3-ERGEBNIS.md` / `.html` (10 Screenshots als data-URI, 14 echte Code-Snippets, offline), `PHASE3-TESTPROTOKOLL.txt`, aktualisiertes `README.md` / `GODOT-IMPORT.txt` / `project.godot`, `tests/Phase3Smoke.gd`, `tools/build_phase3_report.py` und 11 neue `screenshots/phase3_*.png`.

**Nicht in PHASE 3, bewusst nach hinten gestellt:** Skilltree-UI (PHASE 4), Tier-States/Interaktion (PHASE 5), pH-/N-P-K-/Mykorrhiza-/Katastrophen-*Simulation* (spätere volle Simulation, Schalter liegen bereit), Tag/Nacht-Zyklus (vom User ausdrücklich ausgeschlossen).

---

# REVISION 3 — drei Korrekturen vor PHASE 4 (2026-11-07)

## 54. Stufenloser Wasserpegel („Ruckler" behoben)

**Problem:** Der User meldete, dass es bei jeder Ab-/Zunahme eines Reservoirs „ruckelt". Drei Ursachen überlagerten sich:
1. `WorldState._recompute_level()` rechnete `dry_count = n - ceil(fill*n)` und setzte `waterline_px() = level_row * 16`. Der Spiegel sprang also in **16px-Schritten**; dazwischen passierte gar nichts.
2. `TerrainContours` entschied pro 4px-Zelle binär `is_wet = (ly+2) >= line` → selbst bei einem kontinuierlichen Pegel wäre die Kante in 4px-Stufen gewandert.
3. `reservoir_level_changed` wurde bei jedem Zeilenwechsel an **alle 5 Chunks** gesendet; `Chunk.refresh_reservoirs()` lief durch `128 × 88` Tiles und rief pro Tile `generator.reservoir_at()` (Noise) auf → ein echter CPU-Spike genau im Moment des Sprungs.

**Lösung:**
- `_build_group()` baut zusätzlich ein **Zeilen-Histogramm** (`rows: [{y, count}]`). `_compute_level_px()` summiert von unten nach oben ganze Zeilen auf und interpoliert in der Zeile, in der das Restvolumen endet: `level = y*16 + 16*(1-f)` mit `f = (wet - acc)/count`. Ergebnis: **stetige, volumengerechte, monotone** Pegelfunktion; bei 100 % exakt `top*16` (REV2-Smoke bleibt grün), bei 0 % `bottom*16+16`.
- `level_row = floor(level_px/16)` bleibt **nur noch** für `is_dry()` und die Atlas-Slots. Damit bleiben REV2- und P2-Smokes („trocken ausschließlich oben", `SLOT_DRY_WATER`) unverändert gültig.
- `TerrainContours` berechnet `wet_h = clamp(ly+4-line, 0, 4)`, zeichnet Trocken+Blau **anteilig in derselben Zelle** und die Wasserlinie bei `line` auf 1px genau. `partial`-Zellen werden von den alten Rim-/Surface-Regeln ausgenommen, damit keine doppelte oder falsch platzierte Linie entsteht.
- **Zwei Signale statt einem:** `reservoir_volume_changed` (fein, bei jeder Volumenänderung) löst nur `queue_redraw()` der Konturen aus, gedrosselt auf ~25 Hz; `reservoir_level_changed` (grob, nur beim Zeilenwechsel) löst die Tile-Slot-Umschaltung aus. `Chunk` merkt sich beim Aufbau seine Reservoir-Kacheln in `_water_cells` und iteriert nur noch diese statt des ganzen Chunks.

**Messung:** 200 Feinschritte à 0,5 % Volumen, größter Pegelschritt **2,42 px** (vorher 16 px), 199/200 Werte fraktional. Xvfb-Vergleich 50 % → 53 %: blaue Oberkante **y=554 → y=551 px** (3 px statt 0/16 px), identisch in 5 Spalten. Bei realem Regen (~1 %/s) sind das ~0,02 px/Frame.

**Regression gefunden und behoben:** Beim Umbau von Schritt 4 fehlte kurz der `CAVE_FILL`-Zweig, sodass Höhlen nur als Umriss erschienen. Nach Fix neu gerendert und visuell geprüft (`rev3_rain_refill_smooth.png`, `rev3_spring_regression.png`).

## 55. Winter: keine Reservoir-Entnahme

`WaterSystem.tick()` prüft `time_manager.is_winter()` und überspringt dann (a) die gesamte Wurzel-Schleife mit `world_state.consume()` und (b) `tick_passive()` (Boden-Versickerung bei Frost). `last_reservoir_rate` bleibt 0. Regen füllt **weiterhin** auf – der Niederschlag fällt ja auch im Winter, und der User hatte das Auffüllen ausdrücklich gewünscht. Bodenwasser (`tree.absorb_water`) bleibt erhalten; nur die *Reservoirs* sind tabu, exakt wie gefordert.

`HUD._refresh_reservoir_label()` zeigt im Winter stattdessen `MSG_WINTER_WATER` (DE „Winter: kein Wasser aus Reservoirs", EN „Winter: no water from reservoirs"). Der Text ist bewusst kurz, damit er in die 300px-Labelbreite passt (erste Fassung war abgeschnitten).

Smoke: mit 16 Wurzelsegmenten und Reservoir-Kontakt 8712,0 → **8712,0** im Winter, danach 8712,0 → **8622,9** im Frühling.

## 56. Regen mit Aufprall und Spritzern

`RainEffect` war ein reiner Bildschirmraum-Effekt: Linien zogen bis `y > screen_height` durch den Boden hindurch. Neu:
- Tropfen leben in **Welt-Koordinaten** (`wx`, `wy`). `setup(camera, generator)` wird aus `Main._ready()` verdrahtet; `_to_screen()` rechnet `camera.global_position` und `camera.zoom` ein, damit Pan/Zoom den Regen mitnehmen.
- Aufprallhöhe ist `generator.height_smooth_at(wx)` – die **echte 4px-Geländelinie**, nicht der Bildrand. Beim Erreichen: 3 Spritzer mit `vx ∈ [-110,110]`, `vy ∈ [-215,-105]`, Schwerkraft 1150, Lebensdauer 0,20–0,38 s, plus eine 0,34 s Rippe, die sich von 2 auf 11 px ausbreitet. Danach startet der Tropfen oberhalb des sichtbaren Bereichs neu.
- Arrays sind begrenzt (`MAX_SPLASHES=320`, `MAX_RIPPLES=140`), Spritzer verschwinden beim Wiedereintreffen auf dem Boden. Leichter Wind `WIND=26 px/s` erhält den schrägen Fall.
- Debug-Hooks `debug_step`, `debug_splash_count`, `debug_drops_below_surface`, `debug_surface_y`, `debug_populate` für Smoke und reproduzierbare Screenshots.

Smoke: Aufprallhöhe = 320,0 px = `height_smooth_at(0)`, **316 Spritzer**, **0** Tropfen unter der Oberfläche. Screenshot `rev3_rain_splash.png` + Detailausschnitt `rev3_splash_detail.png`.

## 57. Verifikation REVISION 3

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` / `--quit-after 180` | je Exit 0 / 0 Fehler |
| Dauerregen `--quit-after 300 --rev3-shot-rain-splash` | Exit 0 / 0 Fehler / 11 s |
| 7 Smokes (P0/P1/P2/REV1/REV2/P3/REV3), ohne `--seed` | je Exit 0 / `Ergebnis: OK` |
| `--rev3-smoke` | 19 Checks OK / 0 `FEHLER` |
| 6 Xvfb-Renders 1920×1080 | je Exit 0 / 0 Fehler |
| Pegelmessung 50 % → 53 % | 3 px statt 16 px |
| ZIP: CRC, Root-Lage, `.godot` ausgeschlossen, Extrakt-Import + 7 Smokes | OK |

## 58. Abschluss und PHASE-4-Sperre

Geliefert: `waldspiel-REVISION3.zip` (vollständiges Projekt), `REVISION3-ERGEBNIS.md` / `.html` (7 eingebettete Screenshots, 13 Code-Snippets, offline), `REVISION3-TESTPROTOKOLL.txt`, `tests/Revision3Smoke.gd`, `tools/build_revision3_report.py`, 7 `screenshots/rev3_*.png`, aktualisierte `README.md` / `GODOT-IMPORT.txt` / `project.godot` / `data/localization.csv`.

**Historischer Stand vor PHASE 4 (siehe §64):** damals kein GraphEdit, keine Skilltree-Nodes, keine Glucose-Kosten für Skills. Die pH-/N-P-K-/Mykorrhiza-/Katastrophen-*Simulation* bleibt einer späteren Ausbaustufe zugeordnet.

## 59. REVISION 4 — Diagnose des ganzheitlichen Ruckelns

Der gemeldete Ruckler war **nicht** der schon behobene 16px-Pegelsprung, sondern die Haupt-Thread-Last von `TerrainContours._draw()`. Temporäre `--r4-profile`-Instrumentierung (wieder entfernt) maß pro Chunk und Redraw:

| Teil | vorher |
|---|---|
| Erdschicht-Polygone | 23–24 ms |
| Höhlen-Isolinie | 31–32 ms |
| Wasser-Isolinie | 11–12 ms |
| **Summe pro Chunk** | **66,1–68,6 ms** |

Bei 5 geladenen Chunks ≈ 335 ms pro Neuaufbau; R3 löste `queue_redraw()` bis zu 25×/s aus. `--print-fps` (Xvfb, 1920×1080, `--p3-shot-spring`): ~1–2 FPS / 500 ms pro Frame. Ursache im Code: `_draw_blobs()` erzeugte für **jede 4px-Zelle** mehrere `draw_rect`-Befehle, und `_field()` fragte für jede Zelle den FastNoise an. Godot führt die Befehlsliste zwar in jedem Frame erneut aus, baut sie aber bei `queue_redraw()` komplett neu — genau das war der Ruckler.

## 60. REVISION 4 — Architektur der Perf-Korrektur

- **Zwei CanvasItems:** `TerrainContours` zeichnet `erase + layers + cave` **einmal** (`debug_static_draws <= 1`). Das neue Kind `TerrainWaterPainter` (`src/world/TerrainWaterPainter.gd`) zeichnet ausschließlich Wasser und bekommt alle `queue_redraw()`s. Kinder werden nach dem Parent gezeichnet → Wasser liegt weiter oben. `Chunk._on_level_changed()` ruft jetzt `contours.queue_water_redraw()`.
- **Klassenweiter Cache** `_geo_bank` / `_layer_bank`, Schlüssel `seed|chunkIndex|kind`. Chunks werden beim Kamera-Pan freigegeben und neu erzeugt; die deterministische Isolinien-Geometrie wird dabei nicht neu berechnet. Schichtpolygone werden als fertige `PackedVector2Array`/`PackedColorArray` gespeichert.
- **Batching:** zusammenhängende Zellen gleicher Farbe → ein horizontaler Streifen; Rand-2px-Streifen → horizontale bzw. vertikale Läufe (`_add_h` / `_add_v`). Pro Chunk ~1.400–4.500 statt ~26.000 Befehle.
- **Noise nur an Kanten:** der Wackler ist maximal 0,187; bei `|v| > 0,21` kann er das Vorzeichen nicht kippen, also wird `edge_wobble_at()` übersprungen.
- **Redraw-Drosselung:** nur bei sichtbarer Pegeländerung (≥0,4 px) und höchstens alle 0,08 s, nur auf dem Wasser-Item.
- Das Bild bleibt pixelgleich (R3-Fraktionalzelle, Wasserlinie, Höhlen, CAVE_FILL, Naht-Clipping). A/B auf derselben Maschine: **1 FPS → 7 FPS** (`--p3-shot-spring`, 250 Frames, je 2 Läufe). Der verbleibende Rest ist Füllrate des Software-Rasterizers llvmpipe; auf dem Ziel-Renderer Forward+/Vulkan entfällt er.

## 61. REVISION 4 — Eicheln am Boden statt im Inventar

`InteractionController.STARTING_SEEDS = 0`. `SeasonSystem._starter_entries()` legt zwei feste, seed-unabhängige, **frei liegende** Eicheln bei wx = −224 / +288 px auf `roundf(height_smooth_at(wx)/4)*4`, IDs `starter:0` / `starter:1`. Sie liegen im normalen `seeds`-Dictionary und werden damit unverändert über `collect_at()` → `_collect()` → `set_seed_count(+1)` eingesammelt; `collected` verhindet ein Wiedererscheinen nach Save/Load. In `START_ZONE = [-1,0,1]` werden die zufälligen Noise-Samen unterdrückt, damit im Startbild **genau zwei** liegen; alle anderen Chunks behalten P3 „Samen finden / vergraben" inklusive Herbst-Abwurf. Debug-Hooks `debug_starter_positions()`, `debug_ground_positions()`; neue Screenshot-Presets `--rev4-shot-start/-carry/-stages/-water`.

## 62. REVISION 4 — Klickregel und Wuchsstufen

- **Klickregel:** `_left_click()` ruft bei leerem Boden / Himmel / Baum **nicht mehr** `pick_up_acorn()`; einziger Spieler-Einstieg ist `HUD._on_seed_icon_input()` → `hud_acorn_clicked()`. Das Icon wird beim Tragen orange markiert. Während des Tragens platziert nur ein Klick auf/unter `height_smooth_at(x) − 8 px`; ein Himmelsklick zeigt `MSG_ACORN_GROUND_ONLY` und verbraucht nichts. `HUD_HINT`, `HUD_ACORN_TIP`, `MSG_ACORN_CARRY`, `MSG_NO_SEEDS` sind in DE/EN aktualisiert. Debug-Hooks `debug_click_world()`, `debug_click_seed_icon()`. Die REV1-Pfade (Vogel erst nach Platzierung, Rechtsklick/Esc zurück) bleiben intakt.
- **Wuchsstufen:** `BaseTree.STAGE_WIDTHS = [0.30, 0.46, 0.62, 0.80, 1.0]`, Stufe aus `growth_progress()` (45 % Stamm, 35 % Wurzeln, 20 % Blätter). `_refresh_growth_visuals()` setzt `Sprite2D.scale.x` zentriert auf der Stammachse und verjüngt nach oben; `RootSegment.refresh_sprite()` verjüngt mit der Tiefe und macht Spitzen noch dünner. Jung leicht grünlich (`STAGE_TINT`). `hit_rect()` bleibt 16×16, Save/Load (`from_dict()`) stellt die Stufe wieder her. Debug-Hooks `debug_stage()`, `debug_trunk_width()`, `debug_root_width()`.

## 63. Verifikation REVISION 4 und PHASE-4-Sperre

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` / `--quit-after 180` | je Exit 0 / 0 Fehler |
| 8 Smokes P0/P1/P2/REV1/REV2/P3/REV3/**REV4** (ohne `--seed`) | je Exit 0 / `Ergebnis: OK` / 221 Checks |
| `--rev4-smoke` | 32 Checks OK / 0 `FEHLER` |
| 4 Xvfb-Renders 1920×1080 (`rev4_*.png`) | je Exit 0 / 0 Fehler |
| A/B `--print-fps` (R3-ZIP vs. R4, je 2 Läufe) | 1 FPS → 7 FPS |
| Debug-Zähler | 6 Pegel-Redraws: Statik 0 Neuaufbauten, Wasser >0 |
| ZIP: CRC, Root-Lage, `.godot` ausgeschlossen, Extrakt-Import + 8 Smokes | OK |

`Phase1Smoke` prüft jetzt `get_seed_count() == 0` und setzt für den P1-Tutorial-Test bewusst `set_seed_count(2)` — die ursprüngliche Vogel-/Keimling-Logik wird dadurch unverändert getestet. `tools/build_revision4_report.py`, `REVISION4-ERGEBNIS.md/.html`, `REVISION4-TESTPROTOKOLL.txt`, `tests/Revision4Smoke.gd` und 4 `screenshots/rev4_*.png` sind neu.

**Historischer Stand vor PHASE 4 (siehe §64):** damals kein GraphEdit, keine Skilltree-Nodes, keine Glucose-Kosten für Skills. Die pH-/N-P-K-/Mykorrhiza-/Katastrophen-*Simulation* bleibt einer späteren Ausbaustufe zugeordnet.

## 64. PHASE 4 — Skilltree-Daten, Glucose-Kosten und globale Synchronität

Master-Punkt 6 verlangt **pro Baumart einen eigenen Skilltree**, im MVP **15 Knoten**, Freischalten gegen **Glucose** und Vorbedingungen. `src/systems/SkillNodeData.gd` (`Resource`) speichert `id`, `title_key`, `desc_key`, `cost`, beliebig viele `prerequisites`, `effects` und `graph_position`; `SkillTreeData.gd` bündelt sie pro Art. `tools/generate_skilltree.gd` erzeugt daraus mit Godot 4.7.2 `data/skilltrees/oak.tres` (15 eingebettete Sub-Resources, **14** Verbindungslinien). Die sieben Pflicht-Mutationen sind alle vorhanden: `root_efficiency` (+25 % Wasseraufnahme), `leaf_efficiency` (+20 % Glucose), `symbiosis` (Pilz-Knoten), `parasite_res`, `disease_res`, `wood_hardness`, `spread` (+30 % Keimrate).

`SkillTree.gd` hält den Freischalt-Zustand **nur einmal pro Art** (`static var instance`) und nicht in den Baum-Instanzen. `can_unlock()` prüft Vorbedingungen + Glucose, `unlock()` zieht die Kosten ab, berechnet alle Modifikatoren neu und ruft `apply_effect()` auf **jeden** Baum; neu spawnende Bäume bekommen den Stand über `EventBus.tree_spawned`. Master-Punkt 4.2 stellt ausdrücklich klar: „Glucose ist pro Baum-Instanz, Skilltree pro Art synchron". Deshalb bezahlt der **ausgewählte Baum** die Knoten — es wurde kein widersprüchlicher globaler Glucose-Topf eingeführt. **Aktualisierung REVISION 8 (§74, verbindlich):** Der User hat genau diese P4-Auslegung aufgehoben. Skilltree-Kosten werden jetzt aus dem Pool aller Bäume **derselben Art** bezahlt; der Skilltree bleibt pro Art synchron. Der hier beschriebene „ausgewählte Baum zahlt"-Stand ist historisch und nicht mehr maßgeblich. `SaveManager` schreibt den Fortschritt als `skills` in **Format v5**, stellt ihn beim Laden **vor** den Bäumen wieder her; v4/v3/v2/v1 bleiben lesbar.

## 65. PHASE 4 — Effekte wirken auf echte Werte, nicht nur auf Tooltips

| Effekt-Key | Echte Code-Stelle | Messbarer Wert im Smoke |
|---|---|---|
| `root_water` | `BaseTree.absorb_water()`, `WaterSystem` | +25 %: `absorb_water(1 s, 10/s)` → **12,5 Wasser** statt 10 |
| `glucose` | `BaseTree.photosynthesize()` | +20 %: Glucose-Ausbeute = Blätter × Effizienz × Schwierigkeit × **1,20** |
| `max_leaves` | `BaseTree.can_grow("leaf")` | `MAX_LEAVES + 2` statt hartem Cap |
| `growth_cost` / `root_cost` | `InteractionController` (4 Preisstellen) + `GrowthSystem` (AUTO) | −20 % Wurzel-/Stamm-/Blattpreis |
| `rain_boost` / `reservoir_gain` / `winter_water` | `WaterSystem.tick()` | +30 % Niederschlag, +25 % Reservoir-Entnahme, +30 % Bodenwasser im Winter |
| `spread` | `SeasonSystem.set_spread_bonus()` → Eichelfall/Keimung | **spread_bonus = 0,30** |
| `water_consumption` | `BaseTree.photosynthesize()` | −10 % nach Parasiten-/Krankheits-Resistenz |
| `parasite_risk` / `disease_risk` / `storm_risk` | `SkillTree.resistance()` (echte Zahlen, **0,5** = −50 %) | PHASE 5 nutzt `parasite_risk` / `disease_risk` echt; `storm_risk` bleibt vorbereitet |

`SkillTree.apply_effect()` synchronisiert `skill_glucose_mult`, `skill_root_water_mult`, `skill_water_consumption_mult` und `skill_max_leaves_bonus` auf jeder `BaseTree`-Instanz. `SeasonSystem._sync_skills()` abonniert `skilltree_changed`; `WaterSystem` und die Preisrechner lesen die Modifikatoren direkt. Damit sind die sieben Pflicht-Mutationen keine reinen UI-Flags.

## 66. PHASE 4 — GraphEdit-UI und Bedienung

`src/ui/SkillTreeUI.gd` ist ein `CanvasLayer` (Layer 30) mit **echtem `GraphEdit`**: 15 `GraphNode`s, 14 `connect_node()`-Linien, Minimap, Zoom `0,35 … 1,8` (Schritt 1,15, Start 1,0), mittlere Maustaste zum Pannen, Mausrad und eigene `+ / − / 1:1`-Buttons unten links. `show_menu = false` sowie `show_zoom_buttons/grid/minimap/arrange = false` blenden die eingebaute GraphEdit-Leiste aus — sie überlagerte sonst Titel und erste Knotenzeile. Knoten sind absichtlich `draggable = false`: verschoben wird der Graph, nicht das Layout.

Oben rechts sitzt der HUD-Button **„Skilltree (T)"**; `T` öffnet/schließt, `Esc` schließt. `_on_unlock_pressed()` ruft `SkillTree.unlock(id, selected_tree)`; gesperrte oder zu teure Knoten haben deaktivierte Buttons und Statuszeilen (`Gesperrt (Vorbedingung)` / `Verfügbar` / `✓ Freigeschaltet`). `EventBus.skill_unlocked`, `skilltree_changed`, `tree_selected`, `game_loaded` und `locale_changed` aktualisieren Anzeige und DE/EN-Texte; 57 neue `data/localization.csv`-Zeilen decken Knoten, UI, Toasts und Schnee ab.

## 67. PHASE 4 — Winter: Schnee statt Regen

Der User-Wunsch „ersetze den Regen im Winter mit Schnee" wurde **ohne neues Niederschlags-System** umgesetzt: `WaterSystem.raining`, Zeitdauer, Reservoir-Auffüllung, x1/x3/x10-Echtzeitpartikel und Save/Load bleiben unverändert. `RainEffect.snow_mode` wird aus `TimeManager.is_winter()` bei Saisonwechsel und Niederschlagsstart synchronisiert. Im Winter fallen **240 weiße Flocken** mit 55–135 px/s (statt 620–1040 px/s blauer Linien), schwingen sinusförmig seitlich und bleiben beim Auftreffen auf der exakten `height_smooth_at(wx)`-Linie als langsam verblassende Punkte liegen (`MAX_SETTLE = 220`). **Keine Spritzer, keine Rippen** — Schnee spritzt nicht. HUD/Toast zeigen „Es schneit" bzw. „Es schneit – die Wasserreservoirs füllen sich langsam wieder auf."; `WaterSystem.is_snowfall()` und `EventBus.precipitation_mode_changed` halten HUD und Effekt konsistent.

Die R3-Regeln bleiben exakt erhalten: im Winter **keine Reservoir-Entnahme**, keine passive Versickerung, aber Niederschlag füllt weiter auf (`last_reservoir_rate = 0`). Beim Wechsel zurück in den Frühling werden Schneepunkte gelöscht und Regen-Spritzer wieder erzeugt. Screenshots `p4_snow.png` / `p4_snow-detail.png` zeigen Flocken ohne blaue Linien; `p4_f5.png` zeigt den normalen F5-Start mit neuem Skilltree-Button.

## 68. Verifikation PHASE 4 und PHASE-5-Sperre

| Prüfung | Ergebnis |
|---|---|
| `--headless --path . --import` | Exit 0 / 0 Fehler |
| F5 / `--quit-after 180` ohne Preset | Exit 0 / 0 Fehler |
| 9 Smokes P0/P1/P2/REV1/REV2/P3/REV3/REV4/**PHASE4** (ohne `--seed`) | je Exit 0 / `Ergebnis: OK` / **271 Checks** |
| `--phase4-smoke` | **50 Checks OK** / 0 `FEHLER` |
| 5 Xvfb-Renders 1920×1080 (`p4_f5`, `--phase4-shot-skilltree`, `-locked`, `-snow`, `-snow-detail`) | je Exit 0 / 0 Fehler |
| ZIP `waldspiel-PHASE4.zip`: CRC, `project.godot` im Root, `.godot` ausgeschlossen, Extrakt-Import + 9 Smokes | OK |

Neu: `tests/Phase4Smoke.gd`, `tools/generate_skilltree.gd`, `tools/build_phase4_report.py`, `PHASE4-ERGEBNIS.md/.html`, `PHASE4-TESTPROTOKOLL.txt`, 5 `screenshots/p4_*.png`. `Phase3Smoke` prüft jetzt `version >= 4`, damit v5-Saves die alte Save/Load-Regression nicht brechen.

**Historischer Stand vor PHASE 5 (siehe §70):** damals keine Tiere/StateMachine, kein Mistel-Befall, keine Pilz-Simulation. Die Resistenz- und Symbiose-Werte waren als echte Zahlen vorbereitet.

## 69. PHASE-4-FIXRUNDE — Glucose, sichtbare Blätter, Schnee und Übergang

Der User meldete nach dem Spielen drei Punkte. Alle drei wurden ohne PHASE-5-Features behoben.

**1) Glucose 10 → 0 und Verbrauch am ausgewachsenen Baum.** Ursache war eine Kombination aus Standard-AUTO und einem echten Logikfehler: `Global.auto_mode` stand auf `true`, `GrowthSystem` kaufte bei Erreichen der ~10 Glucose sofort ein Wachstumsteil. Schlimmer noch: `can_grow("leaf")` erlaubte mit `crown_growth` bereits 14 Blätter, aber `add_leaf()` blockte weiterhin hart bei `MAX_LEAVES = 12`; `grow_part()` meldete trotzdem `true`, also zog AUTO Glucose ab, **ohne dass ein Blatt entstand**. Bei einem ausgewachsenen Baum wiederholte sich das endlos.

Fix: `Global.auto_mode = false` (Standard MANUELL, per HUD weiterhin bewusst zuschaltbar; fehlendes Save-Feld lädt ebenfalls `false`). `add_trunk_tile()`, `add_leaf()` und `add_root()` geben jetzt `bool` zurück; `grow_part()` gibt nur bei **echtem Zuwachs** `true` zurück. `add_leaf()` nutzt `MAX_LEAVES + skill_max_leaves_bonus`. Damit verbraucht ein voll ausgewachsener Baum in AUTO **0 Glucose** (Smoke 50,0 → 50,0), und AUTO funktioniert nach Umschalten ansonsten unverändert.

**2) „Keine zusätzlichen Blätter trotz Skill".** `crown_growth` erhöhte nur das Cap, fügte aber keine Blätter hinzu — und wegen des obigen Bugs konnte es sie auch nicht nachwachsen lassen. Der Knoten enthält jetzt zusätzlich `grant_leaves = 2.0`. `SkillTree.apply_effect()` setzt erst `skill_max_leaves_bonus` und ruft dann `BaseTree.apply_skill_leaf_grants(2)` auf: **+2 sofort sichtbare Blätter auf allen Eichen**, inklusive neu gespawnter. `skill_leaf_grants` pro Instanz macht das idempotent (keine Duplikate bei `skilltree_changed`, neuem Baum oder Save/Load) und wird in **Format v5** mitgespeichert; `BaseTree.from_dict()` stellt die Cap-Erhöhung vor dem Blattaufbau wieder her, damit gespeicherte Blätter 13/14 nicht verworfen werden. `SKILL_CROWN_DESC` sagt jetzt in DE/EN ausdrücklich „sofort".

**3) Schnee länger liegen + sanfter Übergang.** `RainEffect` hatte `1,6–3,2 s` Liegezeit und löschte beim Saisonwechsel alle Effekte hart. Neu: `SNOW_SETTLE_MIN/MAX = 5,0/9,0 s`, `MAX_SETTLE = 320`, `MODE_FADE_SECONDS = 3,5`, `SETTLE_MELT_MULTIPLIER = 3,0`. Ein neues `snow_blend` (1 = Schnee, 0 = Regen) wird bei `season_changed` **während laufenden Niederschlags** über 3,5 s nach `move_toward()` geführt; neue Niederschlags-Events snappen dagegen weiterhin sofort auf die aktuelle Jahreszeit. Drops tragen beide Parametersätze, Flocken/Geschwindigkeit/Drift, Regenlinien, Spritzer, Rippen und liegende Punkte werden überblendet. Vorhandener Schnee bleibt erhalten und schmilzt beschleunigt statt zu verschwinden. `EventBus.precipitation_blend_changed(float)` versorgt das HUD; neuer DE/EN-Text `MSG_SNOW_MELT` („Der Schnee geht langsam in Regen ueber.") erscheint als Toast **und** HUD-Label. Neues Preset `--phase4-shot-thaw` (Xvfb mit `--fixed-fps 10`) zeigt Flocken und erste Regenlinien gleichzeitig.

Die R3-Regeln bleiben unangetastet: Winter ohne Reservoir-Entnahme/Versickerung, aber Niederschlag füllt weiter auf; im Frühling sind Spritzer wieder aktiv. `FORMAT_VERSION` bleibt 5 (zusätzliches Feld, alte Saves lesbar). `Phase3Smoke` akzeptiert weiter `version >= 4`.

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` / F5 ohne Preset / `--quit-after 180` | je Exit 0 / 0 Fehler |
| **9/9 Smokes** (P0/P1/P2/REV1/REV2/P3/REV3/REV4/PHASE4) | je `Ergebnis: OK` / **284 OK-Zeilen** / 0 Fehler |
| `--phase4-smoke` | **63 OK-Zeilen**, u.a. AUTO-Standard, 50,0→50,0, Cap 14, `grant_leaves`, 5–9 s, 3,5 s Blend, Tau-Text |
| 6 Xvfb-Renders 1920×1080 (`p4_f5`, `p4_skilltree`, `p4_skilltree-locked`, `p4_snow`, `p4_snow-detail`, **`p4_thaw`**) | je Exit 0 / 0 Fehler |
| ZIP `waldspiel-PHASE4-FIX.zip`: CRC, Root-Lage, `.godot` ausgeschlossen, Extrakt-Import + 9 Smokes | OK |

`data/localization.csv` hatte zu diesem Zeitpunkt 137 Zeilen / 58 PHASE-4-Zeilen. Die vorherige `waldspiel-PHASE4.zip` bleibt als historischer Stand in `deliverables/` erhalten. **PHASE 5 ist inzwischen in §70 dokumentiert und umgesetzt.**

## 70. PHASE 5 — Tiere, Symbiose, Parasiten

Der User bat nach der P4-Fixrunde um den Start von PHASE 5. Zwei Widersprüche im Master-Prompt wurden vorab per Rückfrage geklärt: **alle genannten Tiergruppen** sollten umgesetzt werden, und **Wurm/Ameise bleiben immer da**, während **Specht/Eichhörnchen erst ab Wald-Gesundheit > 50 %** erscheinen. Beides ist hiermit verbindlich dokumentiert.

**Metrik.** `ForestHealth.gd` rechnet `0.02 × ΣBlätter + 0.12 × Baumzahl + 0.08 × Tierarten + 0.04 × Pilz-Patches`, geklemmt auf 0..1. Ein Keimling mit 2 Blättern und 2 Basisarten bleibt bei 0.32 (< 0.5); zwei Bäume mit je 6 Blättern erreichen > 0.5. `forest_health_changed` versorgt HUD und `WildlifeSystem`.

**Tiere.** `WildlifeSystem.gd` spawnte 2 Würmer, 2 Ameisen und 1 `Anthill`; ab > 0.5 zusätzlich 1 Specht und 1 Eichhörnchen. `Animal.gd` ist eine echte StateMachine mit `IDLE / WANDER / EAT / HELP_TREE / CARRY`; Wurm/Ameise geben über `EAT` Futter (`food`), die Kolonie wächst alle 10 simulierten Sekunden um eine Ameise, der Hügel wächst mit. Die Kollision nutzt `BaseTree.get_bounds_rect()`; nur Specht im Hilfsflug und Eichhörnchen beim Transport dürfen direkt an den Baum. Alle Tiere, Hügel, Parasiten und Pilze sind per Linksklick anwählbar.

**Specht & Ferntransport.** `parasite_spawned` schickt den Specht in `HELP_TREE`; bei Ankunft ruft er `ParasiteSystem.remove_parasites_at()` und entfernt einen Parasiten. Das Eichhörnchen geht alle 22 simulierten Sekunden in `CARRY`, Ziel ist `+2304 px` (Chunk 1, nicht Start-Chunk); `debug_force_remote_seed()` und der echte `on_seed_delivered()` benutzen denselben Pfad über `InteractionController.spawn_tree_at()`.

**Parasiten.** `Parasite.gd` kennt `MISTLETOE` (0.35 Glucose/s) und `WORM` (0.22 Glucose/s). Die Spawn-Chance ist `0.15 × disaster_rate × resistance(parasite_risk)`; der Wurm-Entzug skaliert zusaetzlich mit `resistance(disease_risk)`. LEICHT schaltet Parasiten komplett ab. `mushroom_node` ergänzt `nutrients = 0.15`, `SkillTree.apply_effect()` setzt `BaseTree.nutrient_mult = 1.15`, und `FungusPatch.gd` zeichnet sichtbare Pilze. Resistenz (`parasite_res` / `disease_res`) entfernt bereits vorhandene Misteln bzw. Wurmbefall beim Freischalten. Die Formulierung „Specht hilft bei Wurmbefall" wird so interpretiert, dass **frei lebende Würmer nützlich** bleiben und ein separater Borkenlarven-Befall (`WORM`) gemeinsam mit der Mistel weggepickt wird.

**Save v6.** `SaveManager` schreibt zusätzlich `wildlife` (Tiere, Futter, Kolonie, Hügel) und `parasites` (kind + tree_id). Beim Laden werden erst Skilltree und Bäume wiederhergestellt, dann Tiere und Parasiten; v5/v4/v3/v2/v1 bleiben lesbar. `Phase4Smoke` prüft deshalb `version >= 5`, `Phase5Smoke` exakt `6`.

**HUD / Lokalisierung.** Neues Panel oben links: Wald-Gesundheit mit Balken, Futter, Tiere, Parasiten, Pilze. 35 neue DE/EN-Schlüssel (171 CSV-Zeilen insgesamt). `SKILL_MUSHROOM_DESC` nennt jetzt die aktiven +15 % Nährstoffe.

**Bewusste Grenze.** PHASE-5-Milestone = Tiere, Specht, Pilz-Knoten, Mistel. Sturm-/Dürre-/Borkenkäfer-Ereignisse, pH-Wert, N-P-K und Mykorrhiza-Netz bleiben der *vollen Simulation* (Master 4.2) vorbehalten; `storm_risk`, `disaster_rate` und `soil_complexity` sind weiterhin vorbereitet, aber nicht als Ereignis-Simulation aktiv. Es wurde **keine PHASE 6** begonnen.

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` / F5 ohne Preset / `--quit-after 180` | je Exit 0 / 0 Fehler |
| **10/10 Smokes** (P0/P1/P2/REV1/REV2/P3/REV3/REV4/PHASE4/PHASE5) | je `Ergebnis: OK` / **341 OK-Zeilen** / 0 Fehler |
| `--phase5-smoke` | **57 OK-Zeilen**: Basis-Tiere, >50 %-Regel, StateMachine, Futter, Kolonie, Chunk 1, Glucose-Entzug, Specht, Resistenz, Pilze, Save v6, 35 DE/EN-Keys |
| 6 Xvfb-Renders 1920×1080 (`p5_f5`, `p5_wildlife`, `p5_health`, `p5_parasite`, `p5_fungus`, `p5_remote`) | je Exit 0 / 25 Frames / 0 Fehler |
| ZIP `waldspiel-PHASE5.zip`: CRC, Root-Lage, `.godot` ausgeschlossen, Extrakt-Import + 10 Smokes | OK |

## 71. REVISION 5 — Organisches Wachstum & Bodenleben

Der User bat nach dem PHASE-5-Abschluss um vier Änderungen: Würmer **unter der Erde** und sich **langsam durchgraben**, Würmer/Ameisen **deutlich kleiner**, Bäume **insgesamt langsamer** und am Ende **deutlich größer**, sowie **verzweigte, vom Feldraster entkoppelte Wurzeln und Stämme** „so wie in Mycelarium". Die Glucose-Produktion sollte insgesamt verlangsamt werden und **vor allem Wasser, Sonne und Nährstoffe berücksichtigen**; ein Baum mit nur einer winzigen Wurzel soll viel weniger Glucose produzieren und wachsen.

**Rückfrage / Scope.** Per `ask_user` verbindlich gewählt: **„~5× langsamer, ~3× größer"** (nicht 3×/2× und nicht 2×/1,6×) sowie **„Freie organische Geometrie, Tile-Logik bleibt"** (kein kompletter Umbau der Simulation). Auslieferung wie bei PHASE 5 inklusive neuem Bericht, ZIP, Extraktprüfung und GitHub-Push.

**Bodenleben (`Animal.gd`, `WildlifeSystem.gd`).** Würmer erhalten `surface_y`, `burrow_depth` (20–120 px) und `burrow_target`; `reseat()` berechnet die Tiefe nach x neu und wird auch beim Laden benutzt. `_tick_burrow()` bewegt die Tiefe mit `WORM_BURROW_SPEED * 0.5` (3,5 px/s), die horizontale Geschwindigkeit sinkt von 18 auf **8 px/s**, der Heimatbereich von 70 auf 34 px. Alle 0,3 s wird ein Weltkoordinaten-Punkt in `_trail` gelegt (max. 30); `_draw_worm()` zeichnet daraus einen dunklen Gang mit heller, aufgelockerter Krumen-Mitte und Erdkrumen, darüber den 12 px langen Wurm mit dunkler Kontur, rosa Kern und Grabekrumen. `_worm_blocked()` sperrt `AIR / WATER / CAVE / ROCK / STONE`, damit der Wurm wirklich durch Erde gräbt. Ameisen schrumpfen auf **9 px**, Specht/Eichhörnchen bleiben bei 40 px. `BODY_SPAN` und angepasste `hit_rect()` machen die Größe messbar. `WildlifeSystem.to_dict()` schreibt `depth` zusätzlich; `from_dict()` ruft `reseat(x, depth)`. `FORMAT_VERSION` bleibt **6** (neue Felder sind optional, alte Saves lesbar). Futterzyklus, Kolonie, Specht-Hilfe und Chunk-1-Transport bleiben unverändert.

**Größer und langsamer (`Tree.gd`, `GrowthSystem.gd`, `oak.tres`).** `MAX_TRUNK 12 → 28`, `TRUNK_STEP = 17 px` ⇒ **476 px** statt 192 px; `MAX_ROOTS 32 → 72`; `root_side_every 4 → 3` für mehr Seitenwurzeln. `MAX_LEAVES` bleibt bewusst 12 (P4-Kronenwuchs-Test erwartet Cap 14), die Krone wird stattdessen über freie Astspitzen, Blatt-Scale und zwei Deko-Blätter pro logischem Blatt sichtbar vergrößert. `GLUCOSE_PACE = 0,2` drosselt das Grundtempo auf ~1/5. Zusätzlich sammelt `GrowthSystem.tick()` pro Baum `growth_vigor += dt * clamp(environment_factor, 0..1)` und kauft erst ab `AUTO_GROWTH_INTERVAL = 1,1`; der Startwert ist bereits voll, damit der P1-Smoke mit sofort verfügbarer Glucose weiterhin kauft. `debug_mark_full()` setzt `growth_vigor = 0`.

**Versorgungs-Bilanz (`BaseTree.environment_parts`).** `photosynthesize()` rechnet jetzt `Blätter × efficiency × growth × difficulty × skill_glucose_mult × GLUCOSE_PACE × environment_factor(sunlight) × dt`. Der Faktor ist das Produkt aus **Wasser** `clamp((water−8)/72, 0..1)`, **Sonne** `clamp(sun, 0..1,25)`, **Nährstoffen** `clamp(soil_fertility() × nutrient_mult, 0,15..1,35)` und **Wurzelmasse** `clamp(√(root_count/18), 0,12..1)`. `soil_fertility()` mittelt echte Bodenarten über alle Wurzelsegmente (`HUMUS 1,25`, `TOPSOIL 1,0`, `CLAY 0,8`, `ROCK 0,35`, `WATER 1,1`, …); ohne Welt bleibt neutral 1,0. Sonne wird nicht mehr separat multipliziert (sonst doppelt). `nutrient_mult` aus `mushroom_node` wirkt jetzt in der Bilanz statt als direkter Glucose-Faktor; `Phase4Smoke`/`Phase5Smoke` wurden auf die neue Formel umgestellt. Messung im Smoke: Keimling mit 1 Wurzel **0,02 Glucose/s**, ausgewachsener, gut versorgter Baum **1,68 Glucose/s** (>3× gefordert, tatsächlich ~80×). Wasser 20 statt 100 senkt die Versorgung um >50 %, Sonne 0 ergibt 0, mehr Nährstoffe erhöhen sie. Das HUD zeigt `Versorgung …% · <knappster Faktor>` (`HUD_SUPPLY` + 5 Limit-Keys), insgesamt **9 neue DE/EN-Schlüssel / 180 CSV-Zeilen**.

**Freie Geometrie (`Tree.gd`, `RootSegment.gd`).** `_h()` hasht `tree_id` + Indizes deterministisch — kein `randf()` im `_draw()`, also kein Flackern und kein zusätzlicher Save-State. `_rebuild_skeleton()` baut eine geschwungene, nach oben verjüngte Stammkurve, bis zu **7 Hauptäste** mit je **2 Zwigen** und Blatt-Ankern; `_layout_leaves()` setzt die (weiterhin 12) Blattsprites an diese Anker. `BaseTree._draw()` zeichnet Wurzelhals, Stamm und Äste als dunkle Kontur plus hellere Faser. `RootSegment._draw()` ersetzt den sichtbaren 16px-Sprite durch eine quadratisch gekrümmte Faser mit Erd-Hof, kräftiger Hauptfaser und **3–5 Hyphen** inklusive Gabeln; Endpunkte liegen per `_jitter()` bewusst abseits des Rasters. Der Sprite bleibt unsichtbar als Breiten-Träger für `debug_root_width()`/Revision4Smoke erhalten; `hit_rect()` bleibt **16×16** und `global_tile()` unverändert. Damit bleiben Wasser/Reservoir, `GrowthCost`, Ghost-Preview, Klick und Save v6 exakt kompatibel — die Entkopplung betrifft die Darstellung, nicht die bewährte Simulation. Dies ist die dokumentierte Auslegung von „entkoppelt von den Feldern".

**Abnahme.** Neuer `tests/Revision5Smoke.gd` (`--rev5-smoke`, 35 OK-Zeilen) prüft Tiefe, Gang-Spuren, Futter, Größen, 28 Schritte, 476 px, Äste, Kronen-Spread, Freiform-Jitter, 16×16-Hitbox, Pace, Wurzel-/Wasser-/Sonnen-/Nährstoff-Einfluss, Wuchskraft, HUD, DE/EN und Save/Load der Wurmtiefe. Dazu sechs Presets `--rev5-shot-f5|mature|branches|roots|worms|supply`.

| Prüfung | Ergebnis |
|---|---|
| `--headless --import` / F5 ohne Preset / `--quit-after 180` | je Exit 0 / 0 Fehler |
| **11/11 Smokes** (P0/P1/P2/REV1/REV2/P3/REV3/REV4/P4/P5/REV5) | je `Ergebnis: OK` / **377 OK-Zeilen** / 0 Fehler |
| `--rev5-smoke` | **35 OK-Zeilen**: Bodenleben, Größen, Versorgung, Wuchskraft, HUD, Save v6 |
| 6 Xvfb-Renders 1920×1080 (`rev5_f5`, `rev5_mature`, `rev5_branches`, `rev5_roots`, `rev5_worms`, `rev5_supply`) | je Exit 0 / 25 Frames / 0 Fehler |
| ZIP `waldspiel-REVISION5.zip` | CRC, Root-Lage, `.godot` ausgeschlossen, frischer Extrakt mit Import + 11 Smokes |

**Bewusste Grenze.** Die volle pH-/N-P-K-/Mykorrhiza-/Katastrophen-Simulation bleibt weiterhin zurückgestellt; `soil_fertility()` ist eine gewichtete Bodenarten-Mittelung, kein N-P-K-Modell. Stamm/Wurzel-Geometrie ist visuell frei, aber die Wasserlogik bleibt tilebasiert. **Es wurde keine PHASE 6 begonnen.** Die PHASE-5-Berichte sind als vorheriger Stand markiert; alle bisherigen ZIPs und Berichte bleiben erhalten.

---

## §72 — REVISION 6: Ziehen, Verdickung, stabile Bodenfauna, Pixelart (gepusht)

**Ausgangslage.** Der User korrigierte nach `5854ac5` (REVISION 5) sieben Punkte: wackelnder Wurm-Gang, waagerecht fixierter Wurm, Ameisen in der Luft, fehlende gezielte Ziehbarkeit von Wurzel/Stamm/Ast (Mycelarium), fehlende Verdickung bereits verbundener Wurzeln und Staemme, fehlende zentrale Pixelart-Austauschbarkeit und zu wenige Blaetter ohne Skilltree-Option. Die R5-Entscheidung `visual_free` bleibt fuer die **Darstellung** richtig, reicht aber nicht mehr als Antwort auf die gezielte Geometrie-Steuerung. Wasser/Reservoir/Save/Kollision bleiben bewusst tilebasiert (16 px).

**Pixelart-Registry (`src/render/PixelArt.gd`, `assets/placeholders/PIXELART.md`).** Alle 19 bestehenden Platzhalterpfade plus neue `worm.png` / `ant.png` liegen in **21 Slots** in `PixelArt.PATHS`; saemtliche Literale in `src/**/*.gd` wurden auf `PixelArt.*` umgestellt. `draw_fibre()` kachelt eine 16x16-Textur entlang einer freien Kurve — Stamm (`trunk.png`), Aeste (`branch.png`) und Wurzel-Hauptfaser (`root.png`) sind damit echte, einzeln austauschbare Texturen. Feine Hyphen, Gang-Spuren und Krumen bleiben Vektor-Details mit zentraler Palette. Tierkoerper sind `Sprite2D`-Kinder (`centered = true`, Nearest-Filter), weil Godot 4.7 bei `draw_texture_*` mit diesem Slot die RGB-Werte durch `modulate` ersetzt (weisser Block); ein Sprite2D rendert die Pixelart korrekt.

**Stabile Bodenfauna (`Animal.gd`).** `_trail` speichert jetzt die **stabile Mittellinie** in Eltern-Koordinaten statt die animierte Koerperposition; `_smooth_trail()` glättet sie per Catmull-Rom. `_sync_worm_motion()` setzt `position.y` nur noch mit `sin(phase)*0,30` (visuell) und berechnet `_body_angle = lerp_angle(..., atan2(vel.y, vel.x), dt*10)` — senkrecht bei vertikalem, waagerecht bei horizontalem Graben. Das Sprite rotiert um (8,8). `_follow_ground()` fragt nach jeder x-Bewegung `height_smooth_at(position.x)` ab und setzt `base_y = surface_y - 1`; Ameisen koennen nicht mehr schweben. `debug_body_angle()`, `debug_ground_gap()`, `debug_trail_point()`, `debug_hold_vertical()`, `debug_nudge_horizontal()` machen die Korrekturen messbar.

**Gezielt ziehen (`Tree.gd`, `RootSegment.gd`, `InteractionController.gd`).** Linksklick auf Wurzel/Baum + Ziehen + Loslassen erzeugt `free_target` pro Wurzelsegment, `trunk_guide` fuer die Stammform und `branch_paths` fuer freie Aeste. `apply_drag_growth()` kostet pro ~16 px Pfadlaenge einen Wachstumsschritt; ein kurzer Klick ohne Bewegung bleibt exakt das alte Verhalten. `_add_root_segment(..., p_free_target)` haelt das logische 16px-Raster fuer Wasser/Save/Hitbox, waehrend die Kurve dem Mauspfad folgt. `grow_wood_along()` entscheidet per Zugrichtung zwischen Stamm-Guide (nach oben, |x| < 70) und freiem Ast. Alle drei Geometrien sind **optionale Felder im Save v6**; alte v6-Saves ohne sie bleiben lesbar. `FORMAT_VERSION` bleibt 6.

**Verdickung.** `RootSegment.refresh_sprite()` rechnet `age = 1 + 0,010*root_count` und `net = 1 + 0,030*descendant_count()` (iterativ, zyklensicher); `_refresh_growth_visuals()` ruft das fuer **alle** Segmente auf, damit jede bereits verbundene Wurzel dicker wird. `BaseTree._trunk_width_at(i, stage)` nutzt `1 + 0,012*trunk_tiles`, sodass alle vorhandenen Stammsegmente bei jedem Stamm-/Ast-Zug dicker werden; `debug_trunk_segment_widths()` / `debug_draw_width()` pruefen die Rohwerte ohne Clamp.

**Skilltree `Dichte Krone` (`tools/generate_skilltree.gd`, `data/skilltrees/oak.tres`, `SkillTree.gd`).** Drei neue Knoten `canopy_i/ii/iii` in Kette an `crown_growth`: je **+12 `max_leaves` und +12 `grant_leaves`**, Stufe II/III zusaetzlich `leaf_density +1`. Ergebnis: **18 Knoten / 17 Verbindungen**, Cap **12 + 2 + 36 = 50**, 2 zusaetzliche Deko-Blaetter pro Anker. `_leaf_anchor_index()` verteilt Blaetter per Goldener-Schnitt-Folge ueber alle Anker; `_rebuild_skeleton()` liefert mehr Anker entlang der Astkurven, Zwigen und Stammspitze. `Phase4Smoke`/`Phase5Smoke` wurden auf 18/17 umgestellt; der alte Cap-Test mit manuell gesetztem Bonus 2 bleibt unveraendert gruen.

**Abnahme.** Neuer `tests/Revision6Smoke.gd` (`--rev6-smoke`, 34 Checks) prueft Gang-Stabilitaet, Rotation, Bodenbindung, Registry, Drag, Verdickung, Skilltree, Save/Load und DE/EN. Dazu drei Presets `--rev6-shot-drag|canopy|worms`. **12/12 Smokes / 411 OK / 0 Fehler**, 180-Frame-F5-Lauf Exit 0, 3 x 25 Xvfb-Frames ohne Fehler. Screenshots `screenshots/rev6_{drag,canopy,worms}.png`, Bericht `REVISION6-ERGEBNIS.html/.md`, Protokoll `REVISION6-TESTPROTOKOLL.txt`.

**Lieferung.** Auf ausdruecklichen User-Wunsch wurde der **gesamte Arbeitsbaum** (Quellen, Assets, Tests, Berichte, Protokoll, drei Screenshots und `deliverables/waldspiel-REVISION6.zip`) als ein Commit auf `main` gepusht; der Remote-HEAD ist damit der Nachfolger von `5854ac5`. Der Push erfolgte mit einem nur temporaer prozess-lokal verwendeten PAT, das nicht im Workspace oder in der Git-Historie abgelegt wurde.

**Bewusste Grenze.** `Global.auto_mode` bleibt standardmaessig aus, `GLUCOSE_PACE` bleibt 0,2, `hit_rect()` bleibt 16x16, `FORMAT_VERSION` bleibt 6 (neue Geometrie-Felder optional), es wurde **keine PHASE 6** begonnen und keine komplette Umstellung der Wasser-/Save-Simulation vorgenommen.

---

## §73 — REVISION 7: endgültig ruhige Gänge, Erdschluss, Licht & Skills (lokal)

**Ausgangslage.** Nach `bcbd1ba` (REVISION 6) meldete der User fünf Punkte: der Wurm-Gang wackle immer noch, die Würmer fielen zu stark auf, Ameisenhügel hingen teilweise in der Luft, der Skilltree brauche sinnvolle Erweiterungen, und zu dicht stehende Bäume sollten wegen Lichtmangel klein bleiben statt zwei volle Kronen übereinander zu zeichnen.

**Warum R6 nicht gereicht hat (`BurrowTrail.gd`, `Animal.gd`).** Der Tunnel war weiterhin ein `_draw()` des Tier-Nodes. Zwar wurden die Weltpunkte rechnerisch um `position` korrigiert, doch `position.y` enthielt `sin(phase * 2.2) * 0,30` und `surface_y` wurde jeden Frame aus dem fließenden `height_smooth_at()` neu berechnet. Der Gang hing damit am Transform und driftete langsam mit. R7 trennt ihn strukturell: `BurrowTrail` ist ein Geschwister-Node im `WildlifeSystem`, `top_level = true`, `z_as_relative = false`, `z_index = 39`, Identitäts-Transformation. Seine Punkte sind unveränderte Weltkoordinaten. Das Sinus-Wackeln ist komplett entfernt, die Tiefe rastet auf `ground_y_at()` (4px-Kante, identisch mit `TerrainSurface`), und neue Stützpunkte entstehen nur bei echter Bewegung ≥ 2 px / ≥ 0,30 s. `debug_freeze_motion()` beweist im Smoke, dass bei laufenden Ticks kein einziger Punkt wandert.

**Dunklere Bodenfauna.** `worm.png` wurde zweimal um ~45 % bzw. ~12 % abgedunkelt (Körper 0,44/0,21/0,18), `PixelArt.WORM_BODY` auf `Color(0,50, 0,30, 0,27)`. Segment-Highlights, Grabekrumen und der Erd-Schleier sind erdfarben statt rosa. Die Ganglinie bleibt absichtlich etwas heller, damit der frische Tunnel sichtbar ist, während das Tier selbst unauffällig bleibt.

**Erdschluss (`WorldGenerator.ground_y_at()`, `Anthill.gd`).** Neu ist eine öffentliche Funktion, die exakt die von `TerrainSurface` gezeichnete 4px-Kante liefert. `Anthill._ground_line()` tastet neun Punkte über die ganze Hügelbreite ab; die Polygon-Basis folgt jedem Höhenschritt, ein dunkler Rim schließt optisch ab. `hit_rect()` und Ameisen (`Animal._follow_ground()`) nutzen dieselbe Kante. `debug_base_gap()` misst 0,000 px.

**Lichtkonkurrenz (`Tree.gd`, `HUD.gd`, `InteractionController.gd`).** `neighbor_shade()` bestimmt den stärksten Schattenwurf innerhalb von 170 px, gewichtet mit der Reife des Nachbarn; identische Positionen werden ignoriert (Save-Probes). `light_factor = clamp(1 − 0,75·shade, 0,38..1)`. `crowd_cap()` begrenzt Stamm, Blätter, Wurzeln und frei gezogene Äste; `photosynthesize()` multipliziert zusätzlich mit diesem Faktor. Ein Keimling in 64 px Abstand zu einem ausgewachsenen Baum bleibt bei **15 Stamm / 6 Blatt / 255 px** statt 28/12/476 px. HUD zeigt `Licht 53% · Nachbarbaum beschattet`, `MSG_CROWD_BLOCKED` ersetzt den stummen Fehlklick. Bereits ausgewachsene Bäume werden nicht nachträglich verkleinert, sondern wachsen einfach nicht weiter.

**Sechs neue Skilltree-Knoten (`tools/generate_skilltree.gd`, `oak.tres`).** Lichtsucher (`crowd_tolerance +0,30`), Schattenlaub (`shade_gain +0,50`), Waldrand (`crowd_tolerance +0,25`, `germination +0,35`), Frühlingssaft (`spring_vigor +0,45`), Humusnetz (`nutrients +0,15`, `root_water +0,10`), Wintervorrat (`winter_water +0,25`, `water_consumption −0,10`). Ergebnis **24 Knoten / 23 Linien**. Die Effekte sind keine reinen Daten: `SkillTree.apply_effect()` setzt `crowd_tolerance`/`shade_gain` auf jeder Instanz, `SeasonSystem.germination_mult` erhöht die Keimchance, `GrowthSystem` beschleunigt die Wuchskraft im Frühjahr, `WaterSystem` und `nutrient_mult` nutzen die bestehenden Modifiers. `SkillTreeUI` bekam zwei neue Ast-Farben; `SKILL_UI_SUBTITLE`/`COUNT`, `Phase4Smoke`, `Phase5Smoke` und `Revision6Smoke` wurden auf 24/23 umgestellt. 16 neue DE/EN-Schlüssel.

**Abnahme.** `tests/Revision7Smoke.gd` (`--rev7-smoke`, 51 Checks), vier Presets `--rev7-shot-worms|anthill|skilltree|crowding`. **13/13 Smokes / 462 OK / 0 Fehler**, Import 0, Skillgen 24/err=0, F5 180 Frames 0, 4×25 Xvfb-Frames 0. Screenshots `screenshots/rev7_{worms,anthill,skilltree,crowding}.png`, Bericht `REVISION7-ERGEBNIS.html/.md`, Protokoll `REVISION7-TESTPROTOKOLL.txt`, ZIP `deliverables/waldspiel-REVISION7.zip`.

**Lieferung.** Auf ausdruecklichen User-Wunsch wurde der **gesamte R7-Arbeitsbaum** (Quellen, Assets, Tests, vier Screenshots, Berichte, Protokoll und `deliverables/waldspiel-REVISION7.zip`) als **ein Commit auf `main` gepusht**; der Remote-HEAD ist damit der Nachfolger von `bcbd1ba`. Der Push nutzte einen vom User bereitgestellten, lokal gespeicherten PAT. Der Token liegt ausschliesslich **ausserhalb des Repos** und ist nicht Teil von Commit, Remote-URL, Git-Config oder Git-Historie.

**Render-Robustheit.** Ein einzelnes konkaves Huegel-Polygon mit 4px-Saegezahn-Basis fuehrte bei manchen Seeds zu `Invalid polygon data, triangulation failed`. `Anthill._draw()` zeichnet deshalb konvexe Dreiecksstreifen zwischen `ground_y_at()`-Basis und einer Glockenkontur; zwei komplette Smoke-Laeufe mit unterschiedlichen Zufalls-Seeds sowie alle vier Renders melden 0 Triangulierungsfehler.

**Bewusste Grenze.** `Global.auto_mode` aus, `FORMAT_VERSION` weiter 6, `GLUCOSE_PACE 0,2`, 16×16-Hitbox, 21 Pixelart-Slots und alle R1–R6-Smokes unverändert. Es wurde **keine PHASE 6** begonnen, keine vollständige Licht-/Schatten-Simulation (nur 1D-Nachbarschaft) und keine Umstellung der Wasser-/Save-Logik vorgenommen.

---

## §74 — REVISION 8: Glucose-Pool, Eichel-Vorrang, Abstand weltweit

**Ausgangslage.** Nach `50979d5` (REVISION 7) meldete der User drei Punkte: Die Glucose für den Skilltree solle aus allen verfügbaren Bäumen zusammengesetzt und dann für alle Bäume dieser Art angewandt werden; manche Eicheln ließen sich nicht aufsammeln, wenn sie direkt unter einem Baum liegen; und die Regel gegen ineinander wachsende Bäume scheine nur für sichtbare Bäume zu gelten — außerhalb des Bildschirms könnten beliebig viele Bäume auf einem Platz wachsen und groß werden.

**Glucose-Pool (`src/systems/SkillTree.gd`, `src/ui/SkillTreeUI.gd`).** Vorher bezahlte `unlock()` ausschließlich der `payer` (der ausgewählte Baum), und die UI zeigte nur dessen `glucose`, obwohl `apply_effect()` schon global auf alle Instanzen lief. R8 führt `pool_trees(payer)` ein: alle `BaseTree` im SceneTree, deren Art (`species_key()` aus `resource_path`, z.B. `oak`) zum Skilltree (`SkillTreeData.species_id`) passt. `pooled_glucose()` ist die Summe, `spend_pooled()` bucht die Kosten anteilig und exakt ab (letzter Baum trägt den Rundungsrest, nie negativ). `can_unlock()`/`unlock()` akzeptieren `payer = null`; ein Kauf ist damit auch ohne Auswahl möglich, sofern mindestens ein Baum der Art existiert. `_apply_to_all()` ist auf dieselbe Art gefiltert; neue Bäume erhalten den Zustand weiterhin über `EventBus.tree_spawned`. Die Skilltree-UI zeigt „Glucose gesamt (alle Eichen)" und prüft `can_unlock()` statt `tree.glucose`. **Bewusst nicht geändert:** Wachstumskosten für Wurzel/Stamm/Blatt/Ziehen bleiben pro Baum — nur der Skilltree nutzt den Pool.

**Eichel-Vorrang (`src/systems/InteractionController.gd`, `src/systems/SeasonSystem.gd`).** Ursache war nicht die Trefferfläche (HIT_SIZE 32×32 war korrekt), sondern die Klick-Reihenfolge: `_unhandled_input()` rief vor `_left_click()` `_drag_candidate()` auf. Lag ein Baum unter der Maus, startete sofort ein Zieh-Vorgang und `collect_at()` wurde nie erreicht; zusätzlich standen in `_left_click()` Tier-/Parasiten-Klicks vor der Eichel. Neu ist `SeasonSystem.has_collectible_at()` (reine Abfrage ohne Seiteneffekt), die in `_unhandled_input()` den Drag-Zweig überspringt; in `_left_click()` steht `collect_at()` jetzt an erster Stelle. Der Debug-Hook `debug_click_world_full()` bildet den echten Mauspfad nach und belegt im Smoke, dass kein Drag gestartet wird.

**Abstandsregel (`src/plants/Tree.gd`, `src/systems/InteractionController.gd`, `src/systems/SeasonSystem.gd`).** Die Beobachtung „nur im Bildschirm" hatte einen konkreten Kern: `neighbor_shade()` enthielt `if d < 1.0 ... continue`, eingeführt damit Save-/Snapshot-Probes an identischer Position den Originalbaum nicht beschatten. `spawn_tree_at()` rastet X jedoch auf 16px — bei der natürlichen Keimung fallen Eicheln `±40 px` um den Mutterbaum und landen deshalb häufig auf **exakt demselben Slot** (`d == 0`). Diese Bäume wurden ignoriert, bekamen volles Licht und wuchsen voll aus; weil das vor allem bei off-screen Bäumen passiert, wirkte die Regel sichtbarkeitsabhängig. R8 behandelt `d == 0` als **maximalen Schatten** und springt nur noch bei `d < 1.0` **und** identischer `tree_id` (echtes Duplikat) heraus. Zusätzlich gibt es erstmals eine echte Pflanz-/Keimungssperre: `MIN_TREE_SPACING = 48 px` mit `nearest_tree_distance()` / `can_spawn_tree_at()` über **alle** Bäume des SceneTree — ohne Kamera, Viewport oder Chunk-Bezug. `plant_seed_at()` prüft vor dem Verbrauch der Eichel (kein Geister-Samen), `SeasonSystem._land()` vor der Keimung; bei zu engem Stand bleibt die Eichel als einsammelbares Item liegen. `spawn_tree_from_dict()` (Save/Load) und Debug-Presets umgehen die Sperre bewusst, damit gespeicherte Stände exakt wiederhergestellt und dichte Stände für Screenshots aufgebaut werden können.

**Robustheitsfix (`src/animals/Animal.gd`).** Beim ersten ZIP-Extrakt fiel ein seltener Flake im REVISION-6-Check „Wurm gräbt waagerecht" auf: Beim Weitergraben springt die auf 4px gerastete Geländekante um ganze Stufen, wodurch `atan2(vel.y, vel.x)` den Wurm gelegentlich schräg stellte. `_sync_worm_motion()` richtet die Rotation jetzt nach der **dominanten** Grabrichtung aus (untergeordnete Komponente wird bei >2× Dominanz nullgesetzt). Danach liefen drei komplette Smoke-Läufe mit unterschiedlichen Seeds fehlerfrei.

**Abnahme.** `tests/Revision8Smoke.gd` (`--rev8-smoke`, 59 Checks), drei Presets `--rev8-shot-pool|acorn|spacing`. **Drei komplette Läufe: je 14/14 Smokes / 521 OK / 0 Fehler**, Import 0, Skillgen 24/err=0, F5 180/0, 3×25 Xvfb-Frames 0. Zusätzlich frischer ZIP-Extrakt mit Import und 14/14 Smokes geprüft. Der Smoke prüft explizit bei `x = 5008` (mehr als 1000 px außerhalb der Kamera): gleicher Platz blockiert, 32 px blockiert, 48 px erlaubt, 400 px erlaubt, `d == 0` ⇒ Schatten > 0,90, zweiter Baum wächst nicht voll aus, und die off-screen Keimung wird blockiert. Screenshots `screenshots/rev8_{pool,acorn,spacing}.png`, Bericht `REVISION8-ERGEBNIS.html/.md`, Protokoll `REVISION8-TESTPROTOKOLL.txt`, ZIP `deliverables/waldspiel-REVISION8.zip`.

**Lieferung.** Auf ausdrücklichen User-Wunsch und mit dem bereitgestellten, lokal gespeicherten PAT als **ein Commit auf `main` gepusht** (Nachfolger von `50979d5`). Der Token liegt ausschließlich außerhalb des Repos und ist nicht Teil von Commit, Remote-URL, Git-Config oder Git-Historie.

**Bewusste Grenze.** `Global.auto_mode` aus, `FORMAT_VERSION` weiter 6, `GLUCOSE_PACE 0,2`, 16×16-Hitbox, 21 Pixelart-Slots, 24 Skilltree-Knoten / 23 Linien und alle R1–R7-Smokes unverändert. Es wurde **keine PHASE 6** begonnen, keine Pro-Art-Skilltree-Instanzen (nur eine Baumart vorhanden) und keine Änderung der Wasser-/Save-Logik vorgenommen.


---

## §75 — PHASE 6: Schwierigkeitsgrade mit voller Bodenchemie & Katastrophen

**Ausgangslage und Abgrenzung.** Der User bat nach dem gepushten `3de6561` (REVISION 8) wörtlich: „Beginne mit der nächsten Phase und arbeite sie sauber durch“. Der Master-Prompt definiert in §10 aber nur PHASE 0–5; §74 hält ausdrücklich fest, dass die volle pH-/N-P-K-/Mykorrhiza-/Katastrophen-Simulation noch zurückgestellt ist, und §13 verlangt, unklare Design-Entscheidungen als sinnvolle Annahme hier zu dokumentieren statt nachzufragen. Deshalb ist PHASE 6 die **Ausarbeitung der Schwierigkeitsgrade aus §4.2**: LEICHT = vereinfacht, NORMAL = halb-realistisch mit seltenen Stürmen/Parasiten, SCHWER = volle Simulation mit pH-Wert, N/P/K, Mykorrhiza und häufigen Katastrophen (Dürre, Sturm, Borkenkäfer). Damit ist die ältere Bedingung „keine PHASE 6 ohne neuen Auftrag" erfüllt. Die „keine PHASE 6 begonnen"-Sätze in §§63–74 sind historische Grenzen ihrer jeweiligen Meilensteine und durch diesen Abschnitt überholt.

**Nicht im P6-Scope.** Die in §3.1/§6/§7/§12/§8 nur als „später" erwähnten Kandidaten bleiben bewusst vorbereitete, aber **nicht implementierte** Ausbaustufen: drei Biome, fünf Tierarten, 40–60 Skillnodes pro Art (weiterhin 24), begehbare Berge, Tag/Nacht und SFX. Auch die Zahl der Baumarten, das 16px-Wurzelraster, Save-Format v6, `Global.auto_mode = false`, `GLUCOSE_PACE = 0.2`, 21 Pixelart-Slots und die R8-Korrekturen werden nicht angetastet.

**Referenzverhalten und Wirkung.** Die vorhandenen `Global.difficulty_factor()`-Werte und `Global.difficulty_toggle("ph" / "nutrients" / "mycorrhiza" / "disasters")` bleiben unverändert, damit die 521 R0–R8-Smoke-Zeilen weiterhin exakt gelten. pH/N/P/K und Mykorrhiza wirken **nur bei SCHWER**; LEICHT bleibt ohne Chemie und Katastrophen, NORMAL behält die bisherige Parasiten- und Versorgungssimulation. Katastrophen starten erst nach einer 300-Sekunden-Grace-Periode und mit `disaster_rate` (LEICHT 0.00, NORMAL 0.35, SCHWER 2.00): kurze Regressionstests bleiben dadurch deterministisch; der P6-Smoke löst Ereignisse gezielt per Debug-Hook aus. NORMAL hat nur Sturm/Borkenkäfer, SCHWER zusätzlich Dürre.

**Bodenchemie (`SoilChemistry.gd`).** Seed-deterministische 64px-Regionen mit pH 4.2–7.8 und N/P/K 20–100. Die Verfügbarkeit kombiniert eine pH-Glocke um das Eichen-Optimum 6.0 mit Liebigs Minimum des knappsten Nährstoffs; sie geht als echter Faktor in `BaseTree.environment_parts()` und damit in Fotosynthese und Wuchskraft ein. Wurzel-/Stamm-/Blattwachstum verbraucht N/P/K in der Region der Wurzelspitze; Humus und Regen regenerieren sie. Bei SCHWER wird der Bodenquerschnitt zusätzlich leicht nach pH/Nährstoff eingefärbt. Rechtsklick zeigt pH, N/P/K und Verfügbarkeit; das Ökologie-Panel zeigt den Wert des ausgewählten Baums.

**Mykorrhiza (`Mycorrhiza.gd`).** Der vorhandene Skill `symbiosis` (bzw. `mushroom_node`) verbindet alle Bäume innerhalb von 280px weltweit — ohne Kamera-/Viewport-Bezug, analog zur R8-Abstandsregel. Das Netz ist ein ortsfester `top_level`-Node2D über dem Boden (kein Wackeln, siehe §73). Bei SCHWER ist Symbiose **nötig**: ohne Netz wird der Nährstofffaktor auf 0,55 gedrosselt; mit Netz steigt er gradabhängig bis 1,40. Bei LEICHT/NORMAL bleibt der Faktor exakt 1,0; der Skill kann dort weiterhin sichtbar freigeschaltet werden.

**Katastrophen (`DisasterSystem.gd`).** Drei Typen mit messbaren Effekten: Dürre entzieht Wasser und stoppt Boden-Regeneration, Sturm senkt Gesundheit, Borkenkäfer entzieht Glucose. `SkillTree.resistance("storm_risk" / "parasite_risk")` halbiert den jeweiligen Schaden; alle Ticks nutzen `TimeManager.scaled_delta()` und respektieren Pause/Zeitspule. Ein laufendes Ereignis wird nicht in einen geladenen Spielstand übernommen (frische Grace), Ereigniszähler und Gesamtschaden bleiben erhalten. Aktive Ereignisse erscheinen als HUD-Zeile, Toast und dezenter, rein prozeduraler Overlay.

**Speichern.** `FORMAT_VERSION` bleibt **6**. „`soil`", „`disasters`" und „`mycorrhiza`" sind optionale Schlüssel im bewährten JSON; alte v6/v5/v4/v3/v2/v1-Saves ohne sie bleiben lesbar. Der P6-Zustand (Regionen, Verbrauch, Ereignisse) wird beim Laden wiederhergestellt, ohne die bestehenden Felder oder die Reihenfolge zu ändern.

**Lieferform.** P6 ist ein eigener Meilenstein, nicht `REVISION9-*`: `PHASE6-ERGEBNIS.md/.html`, `PHASE6-TESTPROTOKOLL.txt`, `tests/Phase6Smoke.gd` (`--p6-smoke`), drei Presets/Screenshots und `deliverables/waldspiel-PHASE6.zip`. Nach Import, 15/15 Smokes, F5-Lauf, Renders und frischem ZIP-Extrakt wird entsprechend der fortgeltenden Freigabe „Ja, alles inkl. GitHub-Push" als ein Commit auf `main` gepusht. Der gespeicherte PAT bleibt außerhalb des Repos.

**Robustheitsfix ohne Test-Aufweichung.** Ein seltener Zufalls-Seed (`1722408048`) lieferte im alten `Revision1Smoke`-Höhlenfenster −48..48 nur 2 Komponenten / 2 Größen. Die Welt hat direkt daneben weitere organische Kammern; `Revision2Smoke` nutzt bereits ein breiteres Fenster. `Revision1Smoke` prüft jetzt −64..64 (15 Komponenten / 8 Größen für genau diesen Seed), behält aber die unveränderten Mindestanforderungen `>= 3` Komponenten und `>= 3` Größen. `WorldGenerator` wurde nicht angefasst. Damit sind auch die drei Final-Läufe mit `20261105` / `20261106` / `20261107` reproduzierbar grün.

**Abnahme.** Import 0; Skillgen `24 / err=0`; **drei komplette Läufe je 15/15 Smokes / 653 OK / 0 Fehler** (R0–R8 weiterhin 521, neu `--p6-smoke` 132); F5 180 Frames / Exit 0 / 0 Fehler; drei Xvfb-Renders `chemistry` / `myco` / `disaster` je 25 Frames / 0 Fehler / 1920×1080; `PHASE6-ERGEBNIS.md/.html` mit 3 Data-URI-Bildern, 11 Snippets und 12 Checks ohne externe Referenzen. `data/localization.csv` hat 225 Zeilen. Das Ökologie-Panel heißt jetzt „PHASE 6 · Boden & Klima" und zeigt pH/N/P/K, Netzstatus und Ereignis. Der frische ZIP-Extrakt wird vor dem Push mit Import + 15/15 Smokes geprüft; der gespeicherte PAT bleibt außerhalb des Repos.
