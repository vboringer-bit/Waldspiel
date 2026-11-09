class_name TreeSpeciesData
extends Resource
## Daten-Resource (.tres) fuer eine Baumart. PHASE 1: Eiche.
## PHASE 3 ergaenzt Buche/Kiefer und schwierigkeitsabhaengige Faktoren.

@export var species_name: String = "Eiche"
@export var photosynthesis_efficiency: float = 0.8
@export var water_consumption_rate: float = 0.35
@export var base_water_gain: float = 0.1
@export var growth_cost: float = 10.0
@export var starting_water: float = 100.0
@export var root_type: String = "Pfahlwurzel + Herzwurzelsystem"
@export var leaf_description: String = "Sommergrün, 2 Blätter beim Keimling"
## PHASE 2: alle N Tiefen-Tiles entsteht eine Seitenwurzel (Herzwurzelsystem).
## Buche/Kiefer (PHASE 3) bekommen andere Werte / andere root_candidates().
@export var root_side_every: int = 4
