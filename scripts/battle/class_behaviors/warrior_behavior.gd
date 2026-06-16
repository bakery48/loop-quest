class_name WarriorBehavior
extends RefCounted

## 雄叫び: add TAUNT, increase ATK stack by 1.
static func execute_unique(warrior: Character) -> String:
	warrior.warrior_atk_stacks = mini(warrior.warrior_atk_stacks + 1, Character.MAX_WARRIOR_STACKS)
	var taunt := StatusEffect.new(StatusEffect.EffectType.TAUNT, 2, 1, "WARRIOR")
	warrior.add_status(taunt)
	return "%s が雄叫びをあげた！ATKバフ(%d段) + 挑発状態" % [warrior.char_name, warrior.warrior_atk_stacks]

## Called when warrior takes damage (passive 血の怒り).
static func on_being_hit(warrior: Character) -> String:
	if warrior.warrior_atk_stacks >= Character.MAX_WARRIOR_STACKS:
		return ""
	warrior.warrior_atk_stacks += 1
	return "%s の怒りが燃え上がる！ATKバフ(%d段)" % [warrior.char_name, warrior.warrior_atk_stacks]

static func get_atk_bonus_from_stacks(warrior: Character) -> float:
	return warrior.warrior_atk_stacks * 0.15

static func reset_battle(warrior: Character) -> void:
	warrior.warrior_atk_stacks = 0
