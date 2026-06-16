class_name Character
extends RefCounted

signal hp_changed(new_hp: int, max_hp: int)
signal mp_changed(new_mp: int, max_mp: int)
signal died()
signal status_added(effect: StatusEffect)
signal status_removed(effect_type: StatusEffect.EffectType)

var class_data: ClassData
var char_name: String

var max_hp: int
var current_hp: int
var max_mp: int
var current_mp: int
var base_atk: int
var base_def: int
var base_spd: int

## Skills equipped in battle slots (max 4). Populated from class_data.starting_skills at run start.
var skill_slots: Array[SkillData] = []
## All owned skills including unequipped.
var skill_inventory: Array[SkillData] = []
var status_effects: Array[StatusEffect] = []

# ── Class-specific state ──────────────────────────────────────
## Warrior: ATK buff stacks (max 5, resets after battle)
var warrior_atk_stacks: int = 0
## Mage: true if magic skill was used last turn
var mage_used_magic_last_turn: bool = false
## Thief: instance IDs of enemies already stolen from this battle
var thief_stolen_enemy_ids: Array[int] = []
## Archer: which enemy instance_id is focused (-1 = none)
var archer_focus_target_id: int = -1
## Archer: current accuracy stacks (0-5)
var archer_focus_stacks: int = 0
## Monk: 0=attack, 1=defense, 2=ki
var monk_stance: int = 0
## Monk: ki gauge
var monk_ki: int = 0
## Sage: skill stored via 予言 (null = none)
var sage_prophecy_skill: SkillData = null
## Alchemist: collected materials
var alchemist_materials: Array[ItemData] = []

const MAX_WARRIOR_STACKS: int = 5
const MAX_ARCHER_STACKS: int = 5
const MAX_ALCHEMIST_MATERIALS: int = 5

static func create(data: ClassData, name_override: String = "") -> Character:
	var c := Character.new()
	c.class_data = data
	c.char_name = name_override if name_override != "" else data.display_name
	c.max_hp = data.base_hp
	c.current_hp = data.base_hp
	c.max_mp = data.base_mp
	c.current_mp = data.base_mp
	c.base_atk = data.base_atk
	c.base_def = data.base_def
	c.base_spd = data.base_spd
	for skill in data.starting_skills:
		c.skill_inventory.append(skill)
		if c.skill_slots.size() < 4:
			c.skill_slots.append(skill)
	return c

# ── Computed stats ────────────────────────────────────────────

func get_effective_atk() -> int:
	var mult := get_atk_multiplier()
	var warrior_bonus := 0
	if class_data.class_type == ClassData.ClassType.WARRIOR:
		warrior_bonus = warrior_atk_stacks * int(base_atk * 0.15)
	return int((base_atk + warrior_bonus) * mult)

func get_effective_def() -> int:
	var mult := get_def_multiplier()
	var monk_penalty := 0
	if class_data.class_type == ClassData.ClassType.MONK and monk_stance == 0:
		monk_penalty = int(base_def * 0.2)
	var monk_bonus := 0
	if class_data.class_type == ClassData.ClassType.MONK and monk_stance == 1:
		monk_bonus = int(base_def * 0.3)
	return int((base_def - monk_penalty + monk_bonus) * mult)

func get_effective_spd() -> int:
	return base_spd

func get_atk_multiplier() -> float:
	var mult := 1.0
	for effect in status_effects:
		mult *= effect.get_atk_multiplier()
	return mult

func get_def_multiplier() -> float:
	var mult := 1.0
	for effect in status_effects:
		mult *= effect.get_def_multiplier()
	return mult

func get_monk_atk_multiplier() -> float:
	if class_data.class_type != ClassData.ClassType.MONK:
		return 1.0
	if monk_stance == 0:
		return 1.3
	return 1.0

func get_monk_mp_cost_multiplier() -> float:
	if class_data.class_type != ClassData.ClassType.MONK and monk_stance != 2:
		return 1.0
	return 0.7

# ── Health & Resources ────────────────────────────────────────

func is_alive() -> bool:
	return current_hp > 0

func take_damage(raw_amount: int) -> int:
	var reduced: int = int(raw_amount / get_effective_def() * 10.0)
	reduced = maxi(1, reduced)
	# Check shield
	var shield := get_status(StatusEffect.EffectType.SHIELD)
	if shield:
		remove_status_by_type(StatusEffect.EffectType.SHIELD)
		status_removed.emit(StatusEffect.EffectType.SHIELD)
		return 0
	current_hp = maxi(0, current_hp - reduced)
	hp_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		died.emit()
	return reduced

func heal(amount: int) -> int:
	var actual: int = mini(amount, max_hp - current_hp)
	current_hp += actual
	hp_changed.emit(current_hp, max_hp)
	return actual

func restore_mp(amount: int) -> int:
	var actual: int = mini(amount, max_mp - current_mp)
	current_mp += actual
	mp_changed.emit(current_mp, max_mp)
	return actual

func spend_mp(amount: int) -> bool:
	var adjusted := int(amount * get_monk_mp_cost_multiplier())
	if current_mp < adjusted:
		return false
	current_mp -= adjusted
	mp_changed.emit(current_mp, max_mp)
	return true

# ── Status Effects ────────────────────────────────────────────

func add_status(effect: StatusEffect) -> void:
	# Merge stackable effects
	if effect.effect_type in [StatusEffect.EffectType.ATK_BUFF, StatusEffect.EffectType.ATK_DEBUFF,
			StatusEffect.EffectType.DEF_BUFF, StatusEffect.EffectType.DEF_DEBUFF,
			StatusEffect.EffectType.FOCUS_AIM]:
		var existing := get_status(effect.effect_type)
		if existing:
			existing.stacks = min(existing.stacks + effect.stacks, 5)
			existing.duration = max(existing.duration, effect.duration)
			status_added.emit(existing)
			return
	status_effects.append(effect)
	status_added.emit(effect)

func remove_status_by_type(type: StatusEffect.EffectType) -> void:
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].effect_type == type:
			status_effects.remove_at(i)
	status_removed.emit(type)

func get_status(type: StatusEffect.EffectType) -> StatusEffect:
	for effect in status_effects:
		if effect.effect_type == type:
			return effect
	return null

func has_status(type: StatusEffect.EffectType) -> bool:
	return get_status(type) != null

func tick_statuses() -> void:
	for i in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].tick():
			var t := status_effects[i].effect_type
			status_effects.remove_at(i)
			status_removed.emit(t)

# ── Skill Management ──────────────────────────────────────────

func can_equip_skill(skill: SkillData) -> bool:
	if skill.allowed_classes.is_empty():
		return true
	return class_data.class_id in skill.allowed_classes

func equip_skill(skill: SkillData, slot: int) -> void:
	assert(slot >= 0 and slot < 4)
	assert(can_equip_skill(skill))
	if not skill in skill_inventory:
		skill_inventory.append(skill)
	if skill_slots.size() <= slot:
		skill_slots.resize(slot + 1)
	skill_slots[slot] = skill

func add_skill_to_inventory(skill: SkillData) -> void:
	if not skill in skill_inventory:
		skill_inventory.append(skill)

# ── Battle Reset ──────────────────────────────────────────────

func reset_battle_state() -> void:
	warrior_atk_stacks = 0
	mage_used_magic_last_turn = false
	thief_stolen_enemy_ids.clear()
	archer_focus_target_id = -1
	archer_focus_stacks = 0
	sage_prophecy_skill = null
	status_effects.clear()
	# Monk stance and ki reset
	monk_stance = 0
	monk_ki = 0
