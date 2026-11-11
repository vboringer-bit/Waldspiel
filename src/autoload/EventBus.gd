extends Node
## Autoload: globale Signals. PHASE 1 nutzt die Spiel-Signals; PHASE 0-Signals
## (chunk_loaded / chunk_unloaded / camera_moved) bleiben unverändert erhalten.

# --- Master-Prompt Punkt 9 ---
signal tree_grew(tree: Node, part: String)
signal rain_started(duration: float)
signal seed_collected(species: String)

# --- PHASE 0 ---
signal chunk_loaded(index: int)
signal chunk_unloaded(index: int)
signal camera_moved(position: Vector2)

# --- PHASE 1 ---
signal seed_placed(position: Vector2)
signal seed_eaten(position: Vector2)
signal tree_spawned(tree: Node)
signal tree_selected(tree: Node)
signal inventory_changed(count: int)
signal glucose_changed(tree: Node, value: float)
signal rain_stopped
signal mode_changed(auto: bool)
signal locale_changed(locale: String)
signal toast(text: String)
signal game_saved
signal game_loaded

# --- PHASE 2 ---
signal reservoir_dried(tile: Vector2i)
signal reservoir_consumed(tile: Vector2i, remaining: float)
signal root_grown(tree: Node, tile: Vector2i, cost: float)
signal ghost_preview(tile: Vector2i, cost: float, affordable: bool, material: String)

# --- REVISION 2 ---
# Ein Becken hat EIN Volumen: der Pegel sinkt von oben nach unten.
signal reservoir_level_changed

# --- REVISION 3: kontinuierlicher Pegel ---
# Wird bei JEDER Volumenaenderung emittiert (nur Konturen neu zeichnen).
# reservoir_level_changed bleibt fuer die seltene Tile-Slot-Umschaltung.
signal reservoir_volume_changed

# --- PHASE 3: Zeit, Jahreszeiten, Reproduktion, Schwierigkeit ---
signal season_changed(year: int, season: int)
signal time_scale_changed(scale: float, paused: bool)
signal difficulty_changed(difficulty: int)
signal acorn_dropped(position: Vector2)
signal seed_found(id: String, buried: bool)

# --- PHASE 4: Skilltree + Winter-Schnee ------------------------------------
signal skill_unlocked(node_id: String)
signal skilltree_changed
signal skilltree_open_requested
signal precipitation_mode_changed(snow: bool)
## PHASE-4-FIX: 0.0 = Regen, 1.0 = Schnee, dazwischen = sanfter Uebergang.
signal precipitation_blend_changed(snow_blend: float)

# --- PHASE 5: Tiere, Symbiose, Parasiten -----------------------------------
signal forest_health_changed(value: float)
signal wildlife_changed
signal animal_spawned(species: String)
signal animal_state_changed(animal: Node, state: int)
signal animal_clicked(animal: Node)
signal food_changed(count: int)
signal anthill_built(position: Vector2)
signal colony_grown(size: int)
signal parasite_spawned(tree: Node, kind: int)
signal parasite_removed(tree: Node, kind: int, by: String)
signal fungus_patch_spawned(tree: Node)
signal seed_carried(from_pos: Vector2, to_pos: Vector2)
signal seed_planted_remote(position: Vector2)

# --- PHASE 6: Bodenchemie, Mykorrhiza, Katastrophen --------------------------
signal soil_changed(region: int)
signal mycorrhiza_changed(links: int)
signal disaster_started(kind: int, duration: float)
signal disaster_ended(kind: int)
