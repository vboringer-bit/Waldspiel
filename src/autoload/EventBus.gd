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
