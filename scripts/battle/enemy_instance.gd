class_name EnemyInstance
extends RefCounted

signal hp_changed(new_hp: int, max_hp: int)
signal died()

var enemy_data: EnemyData
var instance_id: int
var current_hp: int
var status_effects: Array[StatusEffect] = []
var has_been_stolen: bool = false
## Set by Sage's 千里眼 passive so the UI can telegraph the enemy's intent.
var telegraphed_action: EnemyAction = null
## True once the boss crosses its enrage_hp_threshold.
var is_enraged: bool = false

static var _next_id: int = 0

static func create(data: EnemyData) -> EnemyInstance:
	var e := EnemyInstance.new()
	e.enemy_data = data
	e.instance_id = _next_id
	_next_id += 1
	e.current_hp = data.max_hp
	return e

static func reset_id_counter() -> void:
	_next_id = 0

func is_alive() -> bool:
	return current_hp > 0

## Returns actual damage taken. Also triggers enrage if threshold is crossed.
func take_damage(raw_amount: int) -> int:
	var reduced: int = maxi(1, raw_amount - get_effective_def())
	var shield := _get_status(StatusEffect.EffectType.SHIELD)
	if shield:
		_remove_status(StatusEffect.EffectType.SHIELD)
		return 0
	current_hp = max(0, current_hp - reduced)
	hp_changed.emit(current_hp, enemy_data.max_hp)
	# Check enrage threshold
	if not is_enraged and enemy_data.enrage_hp_threshold > 0.0:
		var ratio := float(current_hp) / float(enemy_data.max_hp)
		if ratio <= enemy_data.enrage_hp_threshold:
			is_enraged = true
			var rage := StatusEffect.new(StatusEffect.EffectType.ATK_BUFF, -1, 2, "ENRAGE")
			status_effects.append(rage)
	if current_hp == 0:
		died.emit()
	return reduced

func heal(amount: int) -> int:
	var actual: int = mini(amount, enemy_data.max_hp - current_hp)
	current_hp += actual
	hp_changed.emit(current_hp, enemy_data.max_hp)
	return actual

func get_effective_atk() -> int:
	var mult := 1.0
	for effect in status_effects:
		mult *= effect.get_atk_multiplier()
	return int(enemy_data.atk * mult)

func get_effective_def() -> int:
	var mult := 1.0
	for effect in status_effects:
		mult *= effect.get_def_multiplier()
	return int(enemy_data.def_stat * mult)

## Weighted random selection from enemy_data.actions.
func choose_next_action() -> EnemyAction:
	if enemy_data.actions.is_empty():
		return null
	var total_weight := 0.0
	for action in enemy_data.actions:
		total_weight += action.weight
	var roll := randf() * total_weight
	var cumulative := 0.0
	for action in enemy_data.actions:
		cumulative += action.weight
		if roll <= cumulative:
			return action
	return enemy_data.actions[-1]

func tick_statuses() -> void:
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].tick():
			status_effects.remove_at(i)

func _get_status(type: StatusEffect.EffectType) -> StatusEffect:
	for effect in status_effects:
		if effect.effect_type == type:
			return effect
	return null

func _remove_status(type: StatusEffect.EffectType) -> void:
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].effect_type == type:
			status_effects.remove_at(i)
