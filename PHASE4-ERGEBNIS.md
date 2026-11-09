# PHASE 4 — Ergebnis: Skilltree + Winter-Schnee

**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05**  
15 GraphEdit-Knoten, echte Glucose-Kosten und Effekte, Save v5 — und im Winter Schnee statt Regen. **PHASE 5 wurde nicht begonnen.**

## 1 · Screenshots (echte Godot-Renders)

### F5-Start: Skilltree-Button und unveränderte Welt
*Normaler Start ohne Preset · zwei Eicheln am Boden · HUD zeigt × 0 · neuer Button „Skilltree (T)“ oben rechts*

![F5-Start: Skilltree-Button und unveränderte Welt](screenshots/p4_f5.png)

### GraphEdit-Skilltree: 5 von 15 Mutationen frei
*15 GraphNodes, 14 Verbindungslinien, Minimap, Zweigfarben, Status „Freigeschaltet / Verfügbar / Gesperrt“, 260,0 Glucose*

![GraphEdit-Skilltree: 5 von 15 Mutationen frei](screenshots/p4_skilltree.png)

### Vorbedingungen und Glucose-Kosten sichtbar
*0/15 freigeschaltet · Startknoten verfügbar · alle Folgeknoten gesperrt · 12,0 Glucose*

![Vorbedingungen und Glucose-Kosten sichtbar](screenshots/p4_skilltree-locked.png)

### Winter: Schnee statt Regen
*Weiße, langsam schwingende Flocken · keine blauen Linien · keine Spritzer · HUD „Es schneit“*

![Winter: Schnee statt Regen](screenshots/p4_snow.png)

### Detail: Flocken auf der echten Geländelinie
*Liegengebliebene Schneepunkte auf height_smooth_at(wx) · Wasserreservoir unverändert · keine Rippen*

![Detail: Flocken auf der echten Geländelinie](screenshots/p4_snow-detail.png)

## 2 · Code-Snippets (aus den echten Projektdateien)

### SkillNodeData.gd — ein Knoten als echte Resource

```gdscript
@export var id: String = ""
@export var title_key: String = ""
@export var desc_key: String = ""
@export var cost: float = 10.0
@export var prerequisites: Array[String] = []
@export var effects: Dictionary = {}
@export var graph_position: Vector2 = Vector2.ZERO
@export var branch: String = "water"
```

### generate_skilltree.gd — die ersten Pflicht-Mutationen

```gdscript
	d.nodes.append(_node("root_efficiency", "ROOT", "ROOT", 10.0, [],
		{"root_water": 0.25}, Vector2(0.0, 0.0), "water"))
	d.nodes.append(_node("rain_absorption", "RAIN", "RAIN", 18.0,
		["root_efficiency"], {"rain_boost": 0.30},
		Vector2(330.0, 0.0), "water"))
	d.nodes.append(_node("reservoir_tap", "TAP", "TAP", 26.0,
		["rain_absorption"], {"reservoir_gain": 0.25},
		Vector2(660.0, 0.0), "water"))
	d.nodes.append(_node("deep_roots", "DEEP", "DEEP", 34.0,
		["reservoir_tap"], {"root_cost": -0.20},
		Vector2(990.0, 0.0), "water"))

	d.nodes.append(_node("leaf_efficiency", "LEAF", "LEAF", 10.0, [],
		{"glucose": 0.20}, Vector2(0.0, 220.0), "leaf"))
	d.nodes.append(_node("photosynthesis_plus", "PHOTOSYN", "PHOTOSYN", 18.0,
		["leaf_efficiency"], {"glucose": 0.15},
		Vector2(330.0, 220.0), "leaf"))
```

### SkillTree.gd — Kosten + Vorbedingung prüfen

```gdscript
func can_unlock(id: String, payer: BaseTree) -> bool:
	if unlocked.has(id) or not is_available(id) or payer == null:
		return false
	var nd := node_data(id)
	return nd != null and payer.glucose >= nd.cost


func cost_of(id: String) -> float:
	var nd := node_data(id)
```

### SkillTree.gd — Glucose abziehen und global anwenden

```gdscript
func unlock(id: String, payer: BaseTree) -> bool:
	if not can_unlock(id, payer):
		if not is_available(id):
			EventBus.toast.emit(tr("MSG_SKILL_PREREQ"))
		elif payer == null:
			EventBus.toast.emit(tr("MSG_SKILL_NO_TREE"))
		else:
			EventBus.toast.emit(tr("MSG_SKILL_NO_GLUCOSE"))
		return false
	var nd := node_data(id)
	payer.glucose -= nd.cost
	unlocked[id] = true
	_recompute_mods()
```

### SkillTree.gd — apply_effect() auf echte Baumwerte

```gdscript
func apply_effect(_node_id: String, tree_instance: Node) -> void:
	if not (tree_instance is BaseTree):
		return
	var t := tree_instance as BaseTree
	t.skill_glucose_mult = modifier("glucose")
	t.skill_water_consumption_mult = modifier("water_consumption")
	t.skill_root_water_mult = modifier("root_water")
	t.skill_max_leaves_bonus = int(roundf(bonus("max_leaves")))
```

### SkillTreeUI.gd — echtes GraphEdit ohne überlagerte Leiste

```gdscript
	_graph = GraphEdit.new()
	_graph.name = "SkillGraph"
	_graph.minimap_enabled = true
	_graph.right_disconnects = false
	_graph.zoom_min = 0.35
	_graph.zoom_max = 1.8
	_graph.zoom_step = 1.15
	_graph.zoom = 1.0
	# Die eingebaute GraphEdit-Leiste liegt sonst ueber Titel/Zeile 1.
	# Stattdessen die eigenen +/-/1:1-Buttons unten links verwenden.
	_graph.show_menu = false
	_graph.show_zoom_buttons = false
	_graph.show_grid_buttons = false
	_graph.show_minimap_button = false
	_graph.show_arrange_button = false
	_graph.show_zoom_label = false
	_graph.scroll_offset = Vector2(40.0, 20.0)
	add_child(_graph)
```

### SkillTreeUI.gd — 15 Knoten und 14 Verbindungslinien

```gdscript
func _build_nodes() -> void:
	var st := SkillTree.instance
	if st == null:
		return
	for nd in st.all_nodes():
		var gn := GraphNode.new()
		gn.name = nd.id
		gn.title = tr(nd.title_key)
		gn.position_offset = nd.graph_position
		gn.draggable = false
		gn.resizable = false
		gn.selectable = false
		gn.custom_minimum_size = Vector2(268.0, 132.0)

	for pair in st.connection_pairs():
		var from := String(pair[0])
		var to := String(pair[1])
		if _graph.has_node(from) and _graph.has_node(to):
			_graph.connect_node(from, 0, to, 0)
```

### Tree.gd — Skill-Multiplikatoren und Fotosynthese

```gdscript
var skill_glucose_mult: float = 1.0
var skill_water_consumption_mult: float = 1.0
var skill_root_water_mult: float = 1.0
var skill_max_leaves_bonus: int = 0

func photosynthesize(dt: float, sunlight: float = 1.0,
		growth: float = 1.0) -> void:
	if not _built or leaves_count <= 0 or water <= 10.0:
		return
	age += dt
	# Winter: sunlight = 0 und growth = 0 -> Winterruhe (nichts passiert).
	if sunlight <= 0.0 or growth <= 0.0:
		return
	glucose += float(leaves_count) * species.photosynthesis_efficiency \
		* sunlight * growth * Global.difficulty_factor("photosynthesis") \
		* skill_glucose_mult * dt
	water = maxf(water - species.water_consumption_rate \

func absorb_water(dt: float, rate: float) -> void:
	if not _built:
		return
	water = clampf(water + rate * skill_root_water_mult * dt, 0.0, 100.0)
```

### WaterSystem.gd — Winterruhe + echte Skill-Faktoren

```gdscript
	var winter := time_manager != null and time_manager.is_winter()
	var st := SkillTree.instance
	var soil_factor := Global.difficulty_factor("soil_water") \
		* (st.modifier("winter_water") if st != null and winter else 1.0)
	var rain_mult: float = st.modifier("rain_boost") if st != null else 1.0
	var reservoir_mult: float = st.modifier("reservoir_gain") if st != null else 1.0
	for tree in get_tree().get_nodes_in_group("trees"):
		var rate: float = tree.species.base_water_gain * float(tree.root_count) \
			* soil_factor
		if raining:
			rate *= REGEN_FAKTOR * Global.difficulty_factor("rain_boost") \
				* rain_mult
		# REVISION 2: jedes Wurzelsegment im NASSEN Teil entnimmt dem
```

### SeasonSystem.gd — „Verbreitung“ setzt spread_bonus

```gdscript
func _sync_skills() -> void:
	var st := SkillTree.instance
	set_spread_bonus(st.bonus("spread") if st != null else 0.0)
```

### RainEffect.gd — Winter = Schnee, keine Spritzer

```gdscript
func _sync_mode() -> void:
	snow_mode = time_manager != null and time_manager.is_winter()

func _spawn_landing(wx: float, wy: float) -> void:
	if snow_mode:
		if _settle.size() >= MAX_SETTLE:
			return
		var life := _rng.randf_range(1.6, 3.2)
		_settle.append({
			"px": wx + _rng.randf_range(-2.0, 2.0),
			"py": wy - 1.0,
			"r": _rng.randf_range(1.2, 2.6),
			"life": life, "max": life,
		})
		return
	_spawn_splash(wx, wy)
```

### SaveManager.gd — Format v5 mit skills

```gdscript
		"skills": SkillTree.instance.to_dict() if SkillTree.instance != null else {},
		"trees": trees,
		"world_state": world_state.to_dict() if world_state != null else {},
	}

		SkillTree.instance.from_dict(data.get("skills", {}))

	interaction.clear_carrying(false)
```

### Phase4Smoke.gd — echte Werte statt Tooltips

```gdscript
	# --- 2) Freischalten / echte Effekte -------------------------------------
	interaction.debug_plant_twice()
	var tree: BaseTree = interaction.selected_tree
	_check(tree != null, "Baum fuer Glucose-Bezahlung vorhanden")
	if tree == null:
		_finish()
		return
	tree.glucose = 500.0
	_check(skill_tree.can_unlock("root_efficiency", tree),
		"can_unlock(): Wurzel-Knoten bezahlbar")
	_check(not skill_tree.is_available("deep_roots")
		and not skill_tree.can_unlock("deep_roots", tree),
		"Vorbedingung sperrt Tiefwurzler")
	var before := tree.glucose
```

## 3 · Testprotokoll

```text
WALD-REGENERATION — PHASE 4 — TESTPROTOKOLL
Godot 4.7.2.stable.official.ed1daf0bf · 2026-11-05 · Europe/Berlin
Xvfb 1920x1080x24 · --rendering-driver opengl3 (llvmpipe Software-Rasterizer)
Ziel-Renderer des Projekts: Forward+ / Vulkan

======================================================================
1) IMPORT / F5 / DAUERLAUF
======================================================================
--headless --path . --import                         Exit 0 / 0 Fehler
F5 ohne Preset (Xvfb, 1920x1080, 25 Frames)          Exit 0 / 0 Fehler
--headless --path . --quit-after 180
    -- --seed=20261105 --windowed                     Exit 0 / 0 Fehler
Godot-Import der neuen .tres/.gd/.uid-Dateien         0 Parse/Load-Fehler

======================================================================
2) SMOKE-TESTS (headless, ohne --seed, Legacy-Seed bleibt zufaellig)
======================================================================
--phase0-smoke       Exit 0  Ergebnis: OK    3 OK-Zeilen   0 Fehler
--phase1-smoke       Exit 0  Ergebnis: OK   26 OK-Zeilen   0 Fehler
--phase2-smoke       Exit 0  Ergebnis: OK   25 OK-Zeilen   0 Fehler
--rev1-smoke         Exit 0  Ergebnis: OK   32 OK-Zeilen   0 Fehler
--rev2-smoke         Exit 0  Ergebnis: OK   27 OK-Zeilen   0 Fehler
--p3-smoke           Exit 0  Ergebnis: OK   56 OK-Zeilen   0 Fehler
--rev3-smoke         Exit 0  Ergebnis: OK   20 OK-Zeilen   0 Fehler
--rev4-smoke         Exit 0  Ergebnis: OK   32 OK-Zeilen   0 Fehler
--phase4-smoke       Exit 0  Ergebnis: OK   50 OK-Zeilen   0 Fehler
----------------------------------------------------------------------
9 / 9 Smokes OK · 271 OK-Zeilen (inkl. je 1 Ergebniszeile) · 0 FEHLER · 0 SCRIPT ERROR

PHASE4-Checks im Detail:
[SMOKE] === PHASE 4: Skilltree + Winter-Schnee ===
[SMOKE] SkillTree + data/skilltrees/oak.tres geladen               OK
[SMOKE] Genau 15 MVP-Knoten                                        OK
[SMOKE] Alle 7 Pflicht-Mutationen aus Master-Punkt 6               OK
[SMOKE] 14 Vorbedingungs-Verbindungen                              OK
[SMOKE] Start: nichts freigeschaltet, alle Modifikatoren = 1.0     OK
[SMOKE] Baum fuer Glucose-Bezahlung vorhanden                      OK
[SMOKE] can_unlock(): Wurzel-Knoten bezahlbar                      OK
[SMOKE] Vorbedingung sperrt Tiefwurzler                            OK
[SMOKE] Freischalten erfolgreich                                   OK
[SMOKE] Genau 10 Glucose abgezogen                                 OK
[SMOKE] +25 % Wasseraufnahme im Skilltree                          OK
[SMOKE] apply_effect() wirkt auf die Baum-Instanz                  OK
[SMOKE] Echter Wert: 10 Wasser/s werden zu 12,5                    OK
[SMOKE] Skilltree pro Art synchron (neuer Baum uebernimmt Effekt)  OK
[SMOKE] Effizientere Blaetter freigeschaltet                       OK
[SMOKE] +20 % Glucose am Baum                                      OK
[SMOKE] Echter Wert: Fotosynthese erzeugt 1.92 Glucose             OK
[SMOKE] Verbreitung freigeschaltet (Voraussetzung Blaetter)        OK
[SMOKE] P3-Anschluss set_spread_bonus() = +30 %                    OK
[SMOKE] Ketten-Freischaltung bis Kronenwuchs                       OK
[SMOKE] +2 Blaetter: can_grow('leaf') real erweitert               OK
[SMOKE] Symbiose mit ZWEI Vorbedingungen                           OK
[SMOKE] Parasiten-Resistenz freigeschaltet                         OK
[SMOKE] Resistenzwert -50 % gespeichert (PHASE-5-Anschluss)        OK
[SMOKE] Resistenz wirkt jetzt schon auf den Wasserverbrauch        OK
[SMOKE] 7 Knoten freigeschaltet                                    OK
[SMOKE] GraphEdit: 15 GraphNodes                                   OK
[SMOKE] GraphEdit: 14 Linien                                       OK
[SMOKE] Skilltree-UI oeffnet ueber HUD-Signal / T                  OK
[SMOKE] Zoom veraenderbar                                          OK
[SMOKE] Skilltree-UI schliesst wieder                              OK
[SMOKE] Speichern (Format v5)                                      OK
[SMOKE] Savegame version = 5                                       OK
[SMOKE] Skill-Fortschritt im Savegame (7 IDs)                      OK
[SMOKE] Zurueckgesetzt vor dem Laden                               OK
[SMOKE] Laden (Format v5)                                          OK
[SMOKE] Skill-Fortschritt nach Laden wiederhergestellt             OK
[SMOKE] Winter: Niederschlag ist SCHNEE                            OK
[SMOKE] HUD zeigt „Es schneit“                                     OK
[SMOKE] Schnee erzeugt KEINE Regen-Spritzer                        OK
[SMOKE] Flocken bleiben auf der Oberflaeche liegen                 OK
[SMOKE] Keine Flocken unter der Geländelinie                       OK
[SMOKE] Schnee fuellt Reservoirs weiter auf (R3 erhalten)          OK
[SMOKE] Winter: weiterhin KEINE Reservoir-Entnahme (R3)            OK
[SMOKE] Fruehling: wieder Regen                                    OK
[SMOKE] Schnee-Punkte beim Saisonwechsel entfernt                  OK
[SMOKE] Regen-Spritzer im Fruehling weiter aktiv (REV3)            OK
[SMOKE] Alle 50 P4-Schluessel in DE + EN uebersetzt                OK
[SMOKE] Weiterhin 5 geladene Chunks                                OK
[SMOKE] Ergebnis: OK

======================================================================
3) REPRODUZIERBARE RENDERS (Xvfb + opengl3, --quit-after 25)
======================================================================
Ohne Preset / F5            Exit 0 / 25 Frames / 0 Fehler -> p4_f5.png
--phase4-shot-skilltree     Exit 0 / 25 Frames / 0 Fehler -> p4_skilltree.png
--phase4-shot-skilltree-locked
                            Exit 0 / 25 Frames / 0 Fehler -> p4_skilltree-locked.png
--phase4-shot-snow          Exit 0 / 25 Frames / 0 Fehler -> p4_snow.png
--phase4-shot-snow-detail   Exit 0 / 25 Frames / 0 Fehler -> p4_snow-detail.png
Sichtpruefung: Skilltree 15 Knoten / 14 Linien, keine ueberlagerte
GraphEdit-Leiste; Winter zeigt weisse Flocken, keine blauen Linien,
keine Spritzer; F5-HUD hat den Button "Skilltree (T)".

======================================================================
4) DATEN / SAVE / LOKALISIERUNG
======================================================================
data/skilltrees/oak.tres     15 Knoten, 14 Vorbedingungen, err=0
tools/generate_skilltree.gd  Godot-4.7-ResourceSaver, deterministisch
SaveManager.FORMAT_VERSION   5; skills vor trees wiederhergestellt
data/localization.csv        136 Zeilen, 57 neue PHASE-4-Zeilen (DE+EN)
Phase3Smoke                  version >= 4 (v5 kompatibel)

======================================================================
5) ZIP / EXTRAKT-VERIFIKATION
======================================================================
deliverables/waldspiel-PHASE4.zip: project.godot im Root, CRC OK,
keine .godot-Dateien, keine .zip-in-.zip, alle neuen P4-Dateien drin.
Extrakt -> --headless --import -> alle 9 Smokes: Exit 0 / Ergebnis: OK.

======================================================================
6) BEWUSSTE GRENZE
======================================================================
PHASE 5 wurde NICHT begonnen: keine Tiere, kein Mistel-Befall,
keine Pilz-Simulation, keine pH-/N-P-K-/Mykorrhiza-/Katastrophen-Ereignisse.
Resistenz- und Symbiose-Werte sind als echte Zahlen vorbereitet.
```

## 4 · Abnahme PHASE 4

- ✅ **GraphEdit-Skilltree mit 15 Knoten:** `data/skilltrees/oak.tres` enthält 15 `SkillNodeData`-Resources und **14 Vorbedingungs-Linien**. `SkillTreeUI.gd` zeigt sie zoombar (0,35×–1,8×), pannbar, mit Minimap und eigenen +/−/1:1-Buttons. Die eingebaute GraphEdit-Leiste ist ausgeblendet, damit sie Titel und erste Zeile nicht überdeckt.
- ✅ **Alle 7 Pflicht-Mutationen:** Effizientere Wurzeln (+25 % Wasser), Effizientere Blätter (+20 % Glucose), Symbiose/Pilz-Knoten, Parasiten-Resistenz, Krankheits-Resistenz, Holz-Härte/Sturm-Resistenz, Verbreitung (+30 % Keimrate). Dazu 8 weitere Knoten als MVP-Grundgerüst.
- ✅ **Freischalten kostet Glucose:** `can_unlock()` prüft Vorbedingung + Kontostand, `unlock()` zieht exakt die Kosten ab. Gemäß Master 4.2 bleibt Glucose pro Baum-Instanz, der Skilltree-Fortschritt **global pro Art**: alle Eichen — auch neu gespawnte — teilen ihn.
- ✅ **Effekte wirken auf echte Werte:** 10 Wasser/s werden nach `root_efficiency` zu **12,5**; Fotosynthese × **1,20**; `MAX_LEAVES + 2`; `spread_bonus = 0,30`; −20 % Wurzel-/Stammkosten; echte Regen-, Reservoir- und Winter-Wasserfaktoren; −10 % Wasserverbrauch; Resistenzwerte **0,5** (−50 %) gespeichert.
- ✅ **HUD, Tasten, DE/EN:** Button „Skilltree (T)“ oben rechts, `T` öffnet/schließt, `Esc` schließt, mittlere Maustaste pannt. 57 neue Lokalisierungszeilen; der Smoke prüft **50** P4-Schlüssel in DE und EN. Events aktualisieren UI nach Freischalten, Baumwahl, Laden und Sprachwechsel.
- ✅ **Save/Load v5:** Skill-Fortschritt liegt als `skills` im JSON und wird **vor** den Bäumen wiederhergestellt. v4/v3/v2/v1 bleiben lesbar; `Phase3Smoke` akzeptiert `version >= 4`.
- ✅ **Winter-Schnee statt Regen:** dasselbe Niederschlags-Event, aber 240 langsame weiße Flocken mit Sinus-Drift, **keine blauen Linien, keine Spritzer, keine Rippen**, dafür kurz liegende Schneepunkte auf `height_smooth_at(wx)`. HUD/Toast „Es schneit“. Frühling stellt Regen + Spritzer wieder her.
- ✅ **REVISION 3 erhalten:** Winter ohne Reservoir-Entnahme und ohne passive Versickerung, aber Niederschlag füllt weiter auf (`last_reservoir_rate = 0`). Smoke misst steigenden Füllstand bei Schnee.
- ✅ **Regression & F5:** Import, F5 ohne Preset, 180-Frame-Dauerlauf und **9/9 Smokes** (P0/P1/P2/REV1/REV2/P3/REV3/REV4/PHASE4) laufen mit Exit 0 / **271 OK-Zeilen** / 0 Fehlern. 5 Xvfb-Renders 1920×1080 sind fehlerfrei und visuell geprüft.

## 5 · Hinweise / bewusste Grenzen

- Die Ereignis-Simulation für Parasiten, Krankheit, Sturm, Pilz-Symbiose sowie pH/N-P-K/Mykorrhiza/Katastrophen bleibt PHASE 5. Die Resistenz- und Symbiose-Werte sind bereits echte Zahlen, aber es spawnen noch keine Tiere oder Misteln.
- Xvfb + opengl3/llvmpipe ist ein Software-Rasterizer und nur für reproduzierbare Renders genutzt; Ziel-Renderer des Projekts bleibt Forward+ / Vulkan. Es werden keine FPS-Versprechen für diese Testumgebung abgegeben.
- Keine neuen externen Assets, Addons oder C#-Dateien. Schneeflocken, GraphNodes und Linien werden zur Laufzeit gezeichnet; alle Pfade sind relativ.
- Die ZIP im Ordner deliverables/ ist der eingefrorene Lieferstand. Zum Weiterarbeiten immer den Repo-Root bzw. die neueste ZIP importieren.

## 6 · Lieferumfang

- `deliverables/waldspiel-PHASE4.zip` — vollständiges, Godot-importierbares Projekt (`project.godot` im ZIP-Root, `.godot` ausgeschlossen, CRC OK)
- `PHASE4-ERGEBNIS.html` / `.md`, `PHASE4-TESTPROTOKOLL.txt`, `DECISIONS.md` §§64–68, `README.md`, `GODOT-IMPORT.txt`
- `screenshots/p4_*.png` (5 Renders), `tests/Phase4Smoke.gd`, `tools/generate_skilltree.gd`, `tools/build_phase4_report.py`
- Neue Quellen: `SkillNodeData.gd`, `SkillTreeData.gd`, `SkillTree.gd`, `SkillTreeUI.gd`, `data/skilltrees/oak.tres`; geänderte Systeme: `Tree.gd`, `WaterSystem.gd`, `GrowthSystem.gd`, `InteractionController.gd`, `SeasonSystem.gd`, `SaveManager.gd`, `RainEffect.gd`, `HUD.gd`, `Main.gd/.tscn`, `EventBus.gd`, `localization.csv`

**Nächster Schritt: PHASE 5 — Tiere, Parasiten, Pilz-Symbiose, pH/Katastrophen (noch nicht begonnen).**
