class_name SkillNodeData
extends Resource
## PHASE 4 (Master-Punkt 6 + 9): EIN Knoten des Skilltrees als `.tres`-Daten.
## `effects` ist eine Map effect_key -> Wert. Negative Werte sind Boni nach
## unten (z.B. -0.20 = 20 % guenstiger), positive nach oben.
## `SkillTree.modifier(key)` liefert daraus 1 + Summe aller freigeschalteten
## Werte; `SkillTree.bonus(key)` die reine Summe (fuer additive Werte wie
## zusaetzliche Blaetter).

@export var id: String = ""
@export var title_key: String = ""
@export var desc_key: String = ""
@export var cost: float = 10.0
@export var prerequisites: Array[String] = []
@export var effects: Dictionary = {}
@export var graph_position: Vector2 = Vector2.ZERO
@export var branch: String = "water"
