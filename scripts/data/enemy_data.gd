class_name EnemyData
extends Resource

enum EnemyTier { NORMAL, ELITE, BOSS }

@export var enemy_name: String = ""
@export var tier: EnemyTier = EnemyTier.NORMAL
@export var chapter: int = 1

@export_group("Stats")
@export var max_hp: int = 60
@export var atk: int = 8
@export var def_stat: int = 3
@export var spd: int = 8

@export_group("Rewards")
@export var gold_min: int = 5
@export var gold_max: int = 15
@export var can_be_stolen_from: bool = true

@export_group("Actions")
@export var actions: Array[EnemyAction] = []
