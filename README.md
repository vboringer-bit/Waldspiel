# Wald-Regeneration — PHASE 4

> 2D-Seitenansicht (Himmel **und** Bodenquerschnitt) · Godot **4.7.2 stable** · GDScript · Forward+ / Vulkan
> Inspiriert von Mycelium / Mycelarium. Nach dem Waldbrand: 2 Eicheln **auf dem Boden**, ein hungriger Vogel, ein Keimling mit wachsender Pfahlwurzel — und jetzt Jahreszeiten, Zeitspulen, natürliche Vermehrung, ein **Skilltree mit 15 Mutationen** und **Schnee statt Regen im Winter**.

**Status:** PHASE 0 ✅ · PHASE 1 ✅ · PHASE 2 ✅ · REVISION 1 ✅ · REVISION 2 ✅ · PHASE 3 ✅ · REVISION 3 ✅ · REVISION 4 ✅ · **PHASE 4 ✅ (Skilltree + Winter-Schnee, 9/9 Smokes OK)** · PHASE 5 ⏳ (**noch nicht begonnen**)

**Am Ende dieser Runde gibt es wieder eine komplette ZIP** → `deliverables/waldspiel-PHASE4.zip` (ersetzt `waldspiel-REVISION4.zip` als aktuellen Stand). Dazu `PHASE4-ERGEBNIS.md` / `.html` mit Screenshots und Code-Snippets.

---

## PHASE 4 — Skilltree und Winter-Schnee

1. **GraphEdit-Skilltree mit 15 Knoten.** `data/skilltrees/oak.tres` enthält die 7 Pflicht-Mutationen und 8 weitere Knoten als echte `SkillNodeData`-Resources, dazu **14 Vorbedingungs-Linien**. `SkillTreeUI.gd` zeigt sie als zoombaren, pannbaren Graphen (`0.35× … 1.8×`, Minimap, mittlere Maustaste, Mausrad, `+ / − / 1:1`). Der HUD-Button oben rechts oder **`T`** öffnet, `Esc` schließt. Die eingebaute GraphEdit-Leiste ist zugunsten eigener Buttons ausgeblendet, damit sie nicht über dem Titel liegt.
2. **Freischalten kostet echte Glucose.** `SkillTree.can_unlock()` prüft Vorbedingung + Kontostand des ausgewählten Baums; `unlock()` zieht exakt die Knotenkosten ab. Wie in Master-Punkt 4.2 festgelegt bleibt Glucose **pro Baum-Instanz**, der Skilltree-Fortschritt dagegen **global pro Art**: alle Eichen (auch neu gespawnte) bekommen denselben Stand. `SaveManager` speichert ihn in **Format v5**; alte v4/v3/v2/v1-Saves bleiben lesbar.
3. **Effekte verändern echte Werte.** `root_efficiency` → `12,5 Wasser/s` statt `10`; `leaf_efficiency` → Fotosynthese × `1,20`; `crown_growth` → `MAX_LEAVES + 2`; `spread` → `spread_bonus = 0,30` für Eichelfall/Keimung; `deep_roots`/`trunk_saver` → −20 % Wachstumskosten; `rain_absorption`/`reservoir_tap`/`winter_hardy` → echte Wasserfaktoren; Resistenzen → gespeicherte −50 %-Werte und −10 % Wasserverbrauch. Die Ereignis-Simulation für Parasiten/Krankheit/Sturm/Pilze bleibt bewusst **PHASE 5**.
4. **Im Winter schneit es.** Dasselbe Niederschlags-Event zeichnet jetzt langsame, seitlich schwingende **weiße Flocken** statt blauer Regenlinien, legt beim Auftreffen auf der echten Geländelinie kurz Schneepunkte ab und erzeugt **keine Spritzer/Rippen**. HUD und Toast sagen „Es schneit". Die R3-Regeln bleiben: keine Reservoir-Entnahme, keine Versickerung, aber Auffüllen läuft weiter. Im Frühling regnet es wieder mit Spritzern.
5. **Alles bleibt lauffähig.** DE/EN (57 neue Lokalisierungszeilen), Save/Load, Zeitspulen, 5 Chunks, Nearest, Startmenü und alle 8 bisherigen Smokes sind unverändert geprüft. `--phase4-smoke` ergänzt **50 Checks**; insgesamt **9/9 Smokes · 271 Checks · 0 Fehler**. Screenshots: `p4_f5.png`, `p4_skilltree.png`, `p4_skilltree-locked.png`, `p4_snow.png`, `p4_snow-detail.png`.

**PHASE 5 wurde nicht begonnen** — keine Tiere, kein Mistel-Befall, keine Pilz-/pH-/N-P-K-/Katastrophen-Simulation.

---

## REVISION 4 — vier Korrekturen vor PHASE 4

1. **Das ganze Spiel ruckelt nicht mehr.** Ursache war `TerrainContours._draw()`: **66–69 ms pro Chunk** (5 Chunks ≈ 335 ms) aus zehntausenden `draw_rect`-Befehlen und Noise-Abfragen — und R3 löste diese Neuberechnung bis zu 25×/s aus. Jetzt: statische Geometrie (Atlas/Erdschichten/Höhlen) wird **einmal** gezeichnet, das Wasser hat einen eigenen `TerrainWaterPainter`; Isolinien und Schichtpolygone liegen in einem klassenweiten Cache; gleichfarbige Zellen und Ränder werden zu **Streifen** zusammengefasst; Noise wird nur noch an Kanten abgefragt; Pegel-Redraws sind auf ≥0,4 px / 0,08 s gedrosselt. A/B auf derselben Maschine (Xvfb + llvmpipe, 1920×1080, `--p3-shot-spring`): **1 FPS → 7 FPS**.
2. **Zwei Eicheln liegen am Boden, keine im Inventar.** `STARTING_SEEDS = 0`; `SeasonSystem` legt exakt zwei frei liegende, anklickbare Start-Eicheln auf die fließende Oberkante links/rechts der Startposition. Einsammeln funktioniert unverändert (Linksklick → +1 Inventar). In der Start-Zone werden die zufälligen Noise-Samen unterdrückt, alle anderen Chunks behalten das P3-System.
3. **Inventar-Eichel nur per Klick auf die Eichel.** Ein Klick irgendwo im Bild (leerer Boden, Himmel, Baum) nimmt **keine** Eichel mehr aus dem Inventar; einziger Einstieg ist das Eichel-Icon im HUD (`hud_acorn_clicked()`, beim Tragen orange markiert). Und die schwebende Eichel wird nur noch **auf dem Boden** platziert — ein Klick in den Himmel verbraucht sie nicht mehr. Neuer DE/EN-Hinweis `MSG_ACORN_GROUND_ONLY`, HUD-Hilfszeile aktualisiert.
4. **Stamm und Wurzeln haben 5 sichtbare Wachstumsstufen.** Keimling = 30 % Breite, ausgewachsen = 100 %, dazwischen 46 / 62 / 80 %. Zusätzlich verjüngt sich der Stamm nach oben und die Wurzeln zur Spitze hin; junge Triebe sind leicht grünlich. Das 16px-Kollisionsraster bleibt unverändert und die Stufe überlebt Save/Load.

**PHASE 4 ist inzwischen umgesetzt** – siehe Abschnitt oben.

---

## REVISION 3 — die drei Korrekturen vor PHASE 4

1. **Kein Ruckler mehr am Wasserpegel.** `WorldState` berechnet den Pegel nicht mehr ganzzahlig als `level_row * 16`, sondern **stufenlos in Welt-Pixeln**: aus dem Volumen wird über ein Zeilen-Histogramm der Wasserstand *innerhalb* einer Tile-Zeile interpoliert (`_compute_level_px()`). `TerrainContours` füllt die 4px-Zelle, durch die der Pegel läuft, **anteilig** und zeichnet die Wasserlinie auf Pixelbruchteile genau. Zusätzlich: neues feines Signal `reservoir_volume_changed` (nur Kontur-Redraw, auf ~25 Hz gedrosselt) und die teure `Chunk.refresh_reservoirs()` läuft nur noch beim Zeilenwechsel über eine **gecachte Kachelliste** statt über 128 × 88 Noise-Abfragen. Messung: 3 % Volumen = **3 px** Pegelbewegung statt 0 oder 16 px; 200 Feinschritte, größter Sprung 2,42 px.
2. **Winter: keine Reservoir-Entnahme.** `WaterSystem.tick()` überspringt im Winter die komplette Wurzel-Entnahme und die Boden-Versickerung (Frost); Regen füllt weiterhin auf. Das HUD zeigt `Winter: kein Wasser aus Reservoirs`. Smoke: 8712 → 8712 im Winter, 8712 → 8622,9 im Frühling.
3. **Regen prasselt auf die Oberfläche.** `RainEffect` rechnet jetzt in **Welt-Koordinaten** (Kameraposition + Zoom). Jeder Tropfen fällt bis `generator.height_smooth_at(wx)`, erzeugt dort 3 kleine Spritzer mit Aufwärts-/Seitwärts-Geschwindigkeit plus eine kurz aufblitzende Rippe und startet oberhalb neu. Kein Tropfen fällt mehr durch den Boden. Smoke: Aufprallhöhe = echte Geländelinie, 316 Spritzer, 0 Tropfen unter der Oberfläche.

**PHASE 4 ist inzwischen umgesetzt** – siehe Abschnitt oben.

---

## Starten

1. Godot 4.7.2 stable öffnen → `project.godot` importieren (oder ZIP entpacken und `GODOT-IMPORT.txt` folgen).
2. **F5**. Ein **Startmenü** fragt vor dem Start den Schwierigkeitsgrad ab: **LEICHT / NORMAL / SCHWER**. Es blockiert nichts — man kann jederzeit im HUD umschalten.
3. Das Spiel startet **direkt im Vollbild** und skaliert auf die Monitorfläche ohne graue Ränder. **F11** schaltet um; `--windowed` ist ein Start-Argument für Tests.
4. Der **Welt-Seed wird bei jedem Neustart neu gewürfelt**. Reproduzierbar: `--seed=20261105`, `--difficulty=leicht|normal|schwer` oder **Laden**.

## Steuerung

| Eingabe | Wirkung |
|---|---|
| **Linksklick auf Eichel-Icon (HUD) oder freien Boden** | Eichel **aufnehmen** (schwebt an der Maus) |
| **Linksklick beim Tragen** | Eichel überall auf der Oberfläche platzieren |
| **Linksklick auf eine frei liegende Eichel / kleinen Hügel** | **PHASE 3:** Eichel einsammeln (Hügel erst, wenn eine Wurzel in Reichweite ist) |
| Rechtsklick / `Esc` beim Tragen | zurück ins Inventar (kein Verbrauch, kein Vogel) |
| MANUELL: Linksklick Wurzel / Krone | Wurzel bzw. Blatt wachsen; Kosten nach Boden (Ghost-Preview) |
| AUTO | Baum verteilt Glucose selbst |
| Rechtsklick (ohne getragene Eichel) | Info: Baumwerte / Bodenmaterial / Tiefe / Kosten / vergrabener Samen |
| `W A S D` / Maus am Rand | Kamera schwenken |
| Mausrad | Zoom `0.5x … 2.0x` |
| `R` | Regen / Schnee sofort auslösen (Dev-Hook), je nach Jahreszeit |
| **`T` / HUD „Skilltree (T)"** | Skilltree-UI öffnen/schließen |
| **Skilltree: mittlere Maustaste / Mausrad** | Graph verschieben / zoomen (zusätzlich `+ / − / 1:1`) |
| **Leertaste** | **PHASE 3:** Pause an/aus (auch HUD-Button) |
| **HUD `x1 / x3 / x10`** | **PHASE 3:** Zeitspulen; alle Simulationen nutzen `delta * time_scale` |
| **HUD „Schwierigkeit: …“** | **PHASE 3:** LEICHT → NORMAL → SCHWER → LEICHT |
| `F11` | Vollbild an/aus |
| HUD | AUTO/MANUELL, DE/EN, Speichern, Laden |

**Vogel-Timing:** Die **erste platzierte** Eichel wird weiterhin vom Vogel geklaut — aber erst **nach** dem Platzierungsversuch. **PHASE-3-Korrektur:** er fliegt jetzt kamera-/viewport-abhängig **bis hinter den linken Bildrand**, statt mitten in der Luft zu verschwinden. Danach keimt die zweite Eichel.

---

## Die zwei Korrekturen VOR PHASE 3

1. **Wasserreservoirs füllen sich bei Regen wieder auf.** Vorher war `WorldState.refill()` mit `1.2 * delta` für ein großes Becken praktisch unsichtbar und lief vor/neben der Wurzelentnahme. Jetzt gilt `RAIN_REFILL_PER_TILE = 0.9`, skaliert mit der **Becken-Tile-Zahl** und dem Schwierigkeitsfaktor `rain_refill`; `WaterSystem` ruft das Auffüllen **nach** `consume()` auf, mit `TimeManager.scaled_delta()`. Bei 114 Tiles sind das ~102 Einheiten/s statt vorher 1.2/s — im Smoke 20 % → 40 % in 20 simulierten Sekunden, Pegelzeile 34 → 32. Dazu Toast `MSG_RAIN_REFILL` und HUD-Text „Es regnet".
2. **Vogel fliegt aus dem Bild.** `BirdEvent` berechnet `exit_world_x()` aus Kameraposition, Viewport-Breite und Zoom, startet rechts außerhalb und bewegt den Sprite **pro Frame** mit `FLY_SPEED = 900` bis `x < screen_left - 240`. Erst dann `queue_free()`. Dauer `clamp(dist/900, 1.3, 3.4)` s. Screenshots `phase3_bird_mid.png` (mitten im Flug) und `phase3_bird_exit.png` (am linken Rand) belegen es.

---

## Was PHASE 3 simuliert

### Zeit (`src/systems/TimeManager.gd`)

- **1 Spiel-Jahr = 900 s = 15 Echtzeit-Minuten** (`year_length_seconds`, konfigurierbar), 4 Jahreszeiten à 225 s. **Kein Tag/Nacht-Zyklus** (User-Wunsch).
- Frühling: Wachstum ×1.35, Sonne ×1.25 · Sommer: ×1.00 / ×1.00 · Herbst: ×0.80 / ×0.70, Laub verfärbt sich, Eicheln fallen · **Winter: ×0.00 / ×0.00**, Laubbäume kahl, Wachstum und Fotosynthese blockiert.
- `scaled_delta(delta)` ist die **einzige** Zeitquelle für `GrowthSystem`, `WaterSystem`, `SeasonSystem` und `Tree.age`; Regen-Partikel/Tweens bleiben bewusst in Echtzeit.
- `x1 / x3 / x10` + **Pause (Leertaste)**; `scaled_delta()` liefert bei Pause `0.0`. HUD zeigt `Jahr N · Jahreszeit · xN` und einen Saison-Fortschrittsbalken.

### Samen & natürliche Vermehrung (`src/systems/SeasonSystem.gd`)

- `WorldGenerator.ground_seeds_for_chunk()` verteilt Kandidaten **per Noise** und seed-deterministisch. `SeasonSystem` erzeugt daraus Sprites: frei liegende Eicheln (`acorn.png`) und **flach vergrabene** Eicheln (`seed_mound.png`, `ty = surface_tile_y_at + 2`) — nur mit einer Wurzel in Reichweite erreichbar.
- Linksklick sammelt ein (`EventBus.seed_found` / `seed_collected`), Rechtsklick auf einen Hügel gibt den Hinweis. Bereits gesammelte IDs werden gemerkt und im **Savegame (v4/v5)** gespeichert, damit sie nach Chunk-Reload nicht wieder auftauchen.
- **Herbst:** alle 12 simulierten Sekunden Eichelfall unter der Krone (Tween-Fall auf `height_smooth_at()`), max. 14 pro Herbst. Reife ab **~3 Spiel-Jahren** (`MATURE_AGE_YEARS = 3.0`); junge Bäume werfen seltener ab. Manche Eicheln keimen, wenn `sunlight > 0.4` und nicht Winter (Basis 22 %, × Schwierigkeit × reservierter Skill „Verbreitung"). Sonst bleiben sie liegen.
- Der Skill **„Verbreitung"** setzt jetzt über `SeasonSystem.set_spread_bonus()` den echten `spread_bonus = 0,30`; der Schalter kommt aus dem PHASE-4-Skilltree.

### Schwierigkeitsgrade (`src/autoload/Global.gd`, `src/ui/StartMenu.gd`)

| | LEICHT | NORMAL | SCHWER |
|---|---|---|---|
| Fotosynthese / Bodenwasser | ×1.50 / ×2.00 | ×1.00 / ×1.00 | ×0.70 / ×0.60 |
| Regen-Boost / Regen-Auffüllung | ×1.20 / ×1.30 | 1.00 | ×0.80 / ×0.80 |
| Wachstumskosten / Wasserverbrauch | ×0.80 / ×0.70 | 1.00 | ×1.35 / ×1.40 |
| Eichel-Chance / Keimung / Samendichte | ×1.50 / ×1.40 / ×1.45 | 1.00 | ×0.60 / ×0.60 / ×0.70 |
| Katastrophen-Rate (vorbereitet) | 0.00 | 0.35 | 2.00 |
| Boden-Komplexität (vorbereitet) | 0.00 | 0.50 | 1.00 |
| Schalter | keine Katastrophen, kein pH | seltene Stürme/Parasiten | pH, N-P-K, Mykorrhiza, häufige Katastrophen |

> **Bewusste Grenze:** pH-Wert, Nährstoffe (N/P/K), Mykorrhiza-Netz und Dürre/Sturm/Borkenkäfer sind laut Master-Punkt 4.2 Teil der *„vollen Simulation"*. PHASE 3 legt dafür **alle Schalter und Faktoren** in `Global.difficulty_toggle()` / `difficulty_factor()` an und speichert die Wahl; die eigentliche Simulation folgt in **PHASE 5**, weil sie Systeme voraussetzt, die es im MVP noch nicht gibt. Das ist in `DECISIONS.md` §52 dokumentiert und wird in `--p3-smoke` geprüft.

### Speichern (`src/systems/SaveManager.gd`, Format **v4**)

Zusätzlich zu Wurzeln, Becken-Volumina und getragener Eichel: `difficulty`, `time` (`year`, `season`, `total_elapsed`, `season_elapsed`, `time_scale`, `paused`) und `seeds` (verbleibende + gesammelte IDs). **v3/v2/v1-Saves bleiben lesbar** und bekommen NORMAL/Frühling/Jahr 1 als Defaults.

### HUD / Vollbild-Korrektur

`BAR_HEIGHT = 148` (dritte Reihe): Schwierigkeit, `x1/x3/x10`, Pause, Saisonbalken. `StartMenu` ist ein nicht-blockierendes `CanvasLayer` (Layer 20). **Zusatzbefund:** bei 2560×1440 schnitt die alte `Main._fit_display()` mit `content_scale_factor = 1.333` die HUD rechts ab (sichtbarer Viewport nur 1440×810). Fix: Faktor `1.0` — `canvas_items` + `expand` skaliert bereits selbst. Bei 2560×1440 und 3440×1440 verifiziert.

---

## Weiterhin gültig (P0/P1/P2/REV1/REV2)

- **REVISION 2:** weiche 4px-Kanten für Höhlen/Wasser/Erdschichten (`TerrainContours.gd`), Höhlen ~50 % seltener (`cave_area_scale = 0.5`, Radien × √0.5), Wasser als **ein Becken** mit gemeinsamem Volumen und zeilenweise sinkendem Pegel (`WorldState.gd`). Jetzt zusätzlich **sichtbares Regen-Auffüllen**.
- **REVISION 1:** Vollbild ohne graue Ränder, organische Blob-Höhlen, fließende Oberfläche (`height_smooth_at()`, 4px), Eichel-Schwebe + freie Platzierung, Vogel erst nach Platzierung.
- **PHASE 2:** echte Wurzeln (`Tree → Roots → RootSegment`), Bodenpreise (Asche 8 … Stein 30 Glucose), Ghost-Preview, 5 Chunks à 2048 px, Nearest + Forward+, DE/EN.

## Ordnerstruktur

```
waldspiel/
├── project.godot                    # Godot 4.7.2, Forward+, Fullscreen, Nearest
├── GODOT-IMPORT.txt                 # Import-Anleitung (liegt auch in der ZIP)
├── DECISIONS.md                     # alle Annahmen (P0/P1/P2 + REV1/2 + PHASE 3 §§46-53)
├── REVISION3-ERGEBNIS.md + .html    # Bericht DIESER Runde (Screenshots + Snippets)
├── REVISION3-TESTPROTOKOLL.txt
├── PHASE3-ERGEBNIS.md + .html       # Bericht der vorigen Runde
├── PHASE3-TESTPROTOKOLL.txt
├── tools/build_revision3_report.py
├── REVISION2-ERGEBNIS.md + .html    # historische Berichte
├── tools/
│   ├── generate_placeholders.py     # erzeugt alle 19 PNGs neu (seed_mound.png neu)
│   ├── build_phase3_report.py       # Bericht mit 10 eingebetteten Screenshots
│   └── build_zip.py                 # vollständige Godot-ZIP
├── assets/placeholders/             # 19 PNGs + .import/.uid
├── data/localization.csv            # 76 Zeilen (Key, DE, EN), 17 neue P3-Keys
├── src/
│   ├── Main.gd / Main.tscn           # P3-Wiring, Presets, Space, _fit_display()
│   ├── autoload/Global.gd, EventBus.gd
│   ├── systems/                     # TimeManager, GrowthSystem, WaterSystem,
│   │                                # GrowthCost, SeasonSystem (NEU), SaveManager,
│   │                                # InteractionController
│   ├── ui/                          # HUD, StartMenu (NEU), BirdEvent, RainEffect
│   ├── world/, camera/, background/, plants/
├── tests/                           # 6 Smokes inkl. Phase3Smoke.gd (NEU)
├── screenshots/phase3_*.png         # P3-Renders
└── screenshots/rev3_*.png           # 7 neue REV3-Renders
```

## Tests

```bash
godot --headless --path . --import
godot --headless --path . --quit-after 180
godot --headless --path . -- --phase0-smoke       # Regression: OK
godot --headless --path . -- --phase1-smoke       # Regression: OK
godot --headless --path . -- --phase2-smoke       # Regression: OK
godot --headless --path . -- --rev1-smoke         # Regression: OK
godot --headless --path . -- --rev2-smoke         # Regression: OK
godot --headless --path . -- --p3-smoke           # PHASE 3: 55 Checks, OK
godot --headless --path . -- --rev3-smoke         # REVISION 3: 19 Checks, OK
```

`--rev3-smoke` prüft u. a. stufenlose Pegelbewegung in beide Richtungen, getrennte Redraw-Signale, Winter/Frühling-Entnahme, Regen-Aufprallhöhe und Spritzer sowie die REV2-Trocken-Reihenfolge. `--p3-smoke` prüft u. a. die beiden Vorab-Korrekturen, 15-min-Jahr, `scaled_delta` / Pause / x10, Winterruhe & kahlen Baum, alle drei Schwierigkeitsgrade inkl. Schalter, Startmenü, Eichel einsammeln / Hügel erst mit Wurzel, Herbstfall, Save-v4-Roundtrip, 5 Chunks, Nearest, Vollbild-Skalierung, DE/EN. **Wichtig:** Legacy-Smokes ohne `--seed` ausführen (P1 verlangt Zufalls-Seed). Beim ZIP-Extrakt-Test fiel `--rev1-smoke` bei einem ungünstigen Zufalls-Seed auf, weil er nur 26 Höhlen-Zeilen scannte; der Suchbereich ist jetzt wie in P2/REV2 auf `top+5 … top+45` vereinheitlicht (über 8 feste Seeds und 5 Zufallsläufe verifiziert).

Reproduzierbare Screenshots (Godot + Xvfb, `--seed=20261105 --windowed`):

```bash
--p3-shot-difficulty / --p3-shot-spring / --p3-shot-autumn / --p3-shot-winter
--p3-shot-seeds / --p3-shot-rain-refill / --p3-shot-bird-mid / --p3-shot-bird-exit
--rev2-shot-edges                         # Regression
--p3-debug-sizes                          # Viewport-/Skalierungs-Debug
--rev3-shot-rain-splash                   # Regen + Spritzer an der Oberfläche
--rev3-shot-water-a / -b                  # 50 % / 53 % Pegel (3 px Unterschied)
--rev4-shot-start                         # 2 Boden-Eicheln, Inventar × 0
--rev4-shot-carry                         # nur HUD-Icon-Klick -> schwebende Eichel
--rev4-shot-stages                        # duenner Keimling vs. dicker Baum
--rev4-shot-water                         # R3-Regression: geglätteter Pegel
```

## ZIP (vollständig, Godot-importierbar)

```bash
python3 tools/build_zip.py PHASE4   # -> deliverables/waldspiel-PHASE4.zip
```

`project.godot` liegt im **ZIP-Root**, `.godot/`-Cache und generierte `.translation` sind ausgeschlossen; alle Quellen, Assets, `.import`/`.uid`, Tests, Berichte und Screenshots sind drin. CRC-Test ist Teil des Skripts.

**Nächster Schritt: PHASE 5 — Tiere, Parasiten, Pilz-Symbiose und pH-/Katastrophen-Simulation (noch nicht begonnen).**
