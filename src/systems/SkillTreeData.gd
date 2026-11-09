class_name SkillTreeData
extends Resource
## PHASE 4: PRO BAUMART ein eigener Skilltree (Master-Punkt 6).
## `res://data/skilltrees/oak.tres` enthaelt die 15 MVP-Knoten der Eiche.
## Alle Eichen-Instanzen teilen sich denselben Freischalt-Zustand (global,
## synchron) - geregelt in `SkillTree.gd`, nicht in den Baum-Instanzen.

@export var species_id: String = "oak"
@export var species_name_key: String = "SPECIES_OAK"
@export var nodes: Array[SkillNodeData] = []
