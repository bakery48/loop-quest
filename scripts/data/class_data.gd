class_name ClassData
extends Resource

enum ClassType {
	HERO,
	WARRIOR,
	MAGE,
	CLERIC,
	THIEF,
	ARCHER,
	MONK,
	SUMMONER,
	SAGE,
	ALCHEMIST,
}

@export var class_id: String = ""
@export var display_name: String = ""
@export var class_type: ClassType = ClassType.HERO
@export var is_starter: bool = false

@export_group("Base Stats")
@export var base_hp: int = 100
@export var base_mp: int = 50
@export var base_atk: int = 10
@export var base_def: int = 5
@export var base_spd: int = 10

@export_group("Passive")
@export var passive_name: String = ""
@export var passive_description: String = ""

@export_group("Unique Command")
@export var unique_command_name: String = ""
@export var unique_command_description: String = ""
@export var unique_targets_enemy: bool = false  # true if unique command targets an enemy
@export var unique_targets_ally: bool = false   # true if unique command targets an ally

@export_group("Skills")
@export var starting_skills: Array[SkillData] = []
