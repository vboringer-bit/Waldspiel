extends SceneTree
## PHASE 4: erzeugt `res://data/skilltrees/oak.tres` aus den echten
## SkillNodeData-Resources. Aufruf (nach --headless --import):
##   godot --headless --path . --script tools/generate_skilltree.gd --quit-after 5
## So ist die .tres garantiert im korrekten Godot-4.7-Format und enthaelt
## alle 15 Knoten als eingebettete Sub-Resources.

const OUT := "res://data/skilltrees/oak.tres"


func _node(id: String, title: String, desc: String, cost: float,
		prereq: Array, effects: Dictionary, pos: Vector2,
		branch: String) -> SkillNodeData:
	var d := SkillNodeData.new()
	d.id = id
	d.title_key = "SKILL_" + title + "_TITLE"
	d.desc_key = "SKILL_" + title + "_DESC"
	d.cost = cost
	for p in prereq:
		d.prerequisites.append(String(p))
	d.effects = effects
	d.graph_position = pos
	d.branch = branch
	return d


func _initialize() -> void:
	var d := SkillTreeData.new()
	d.species_id = "oak"
	d.species_name_key = "SPECIES_OAK"

	# --- Ast WASSER (Master: effizientere Wurzeln +25 %) ---------------------
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

	# --- Ast GLUCOSE (Master: effizientere Blaetter +20 %) ------------------
	d.nodes.append(_node("leaf_efficiency", "LEAF", "LEAF", 10.0, [],
		{"glucose": 0.20}, Vector2(0.0, 220.0), "leaf"))
	d.nodes.append(_node("photosynthesis_plus", "PHOTOSYN", "PHOTOSYN", 18.0,
		["leaf_efficiency"], {"glucose": 0.15},
		Vector2(330.0, 220.0), "leaf"))
	d.nodes.append(_node("crown_growth", "CROWN", "CROWN", 26.0,
		["photosynthesis_plus"], {"max_leaves": 2.0},
		Vector2(660.0, 220.0), "leaf"))
	d.nodes.append(_node("trunk_saver", "TRUNK", "TRUNK", 34.0,
		["crown_growth"], {"growth_cost": -0.20},
		Vector2(990.0, 220.0), "leaf"))

	# --- Ast VERBREITUNG / RESISTENZ ----------------------------------------
	d.nodes.append(_node("spread", "SPREAD", "SPREAD", 14.0,
		["leaf_efficiency"], {"spread": 0.30},
		Vector2(0.0, 440.0), "resist"))
	d.nodes.append(_node("parasite_res", "PARASITE", "PARASITE", 20.0,
		["spread"], {"parasite_risk": -0.50, "water_consumption": -0.10},
		Vector2(330.0, 440.0), "resist"))
	d.nodes.append(_node("disease_res", "DISEASE", "DISEASE", 26.0,
		["parasite_res"], {"disease_risk": -0.50, "water_consumption": -0.10},
		Vector2(660.0, 440.0), "resist"))
	d.nodes.append(_node("wood_hardness", "WOOD", "WOOD", 32.0,
		["disease_res"], {"storm_risk": -0.50, "root_water": 0.10},
		Vector2(990.0, 440.0), "resist"))

	# --- Ast SYMBIOSE (Master: schaltet Pilz-Knoten frei) -------------------
	d.nodes.append(_node("symbiosis", "SYMBIOSIS", "SYMBIOSIS", 22.0,
		["root_efficiency", "leaf_efficiency"], {"root_water": 0.10},
		Vector2(330.0, 660.0), "symbiosis"))
	d.nodes.append(_node("mushroom_node", "MUSHROOM", "MUSHROOM", 30.0,
		["symbiosis"], {"glucose": 0.10},
		Vector2(660.0, 660.0), "symbiosis"))
	d.nodes.append(_node("winter_hardy", "WINTER", "WINTER", 28.0,
		["mushroom_node"], {"winter_water": 0.30},
		Vector2(990.0, 660.0), "symbiosis"))

	var err := ResourceSaver.save(d, OUT)
	print("[SKILLTREE] ", OUT, " | Knoten=", d.nodes.size(), " | err=", err)
	quit()
