class_name ClericBehavior
extends RefCounted

const PASSIVE_HEAL_PERCENT: float = 0.08  # 8% of max HP per turn

## 癒しのオーラ: auto-heal the lowest HP ally each turn.
static func apply_passive_heal(cleric: Character, party: Array[Character]) -> String:
	if not cleric.is_alive():
		return ""
	var lowest: Character = null
	var lowest_ratio := 1.1
	for member in party:
		if member is Character and member.is_alive():
			var ratio := float(member.current_hp) / float(member.max_hp)
			if ratio < lowest_ratio:
				lowest_ratio = ratio
				lowest = member
	if lowest == null or lowest_ratio >= 1.0:
		return ""
	var heal_amount := int(lowest.max_hp * PASSIVE_HEAL_PERCENT)
	var actual := lowest.heal(heal_amount)
	return "%s の癒しのオーラ！%s のHPを%d回復。" % [cleric.char_name, lowest.char_name, actual]

## 加護: heal target + apply DEF buff.
static func execute_unique(cleric: Character, target: Character) -> String:
	var heal_amount := int(cleric.base_atk * 2.5)
	var actual := target.heal(heal_amount)
	var buff := StatusEffect.new(StatusEffect.EffectType.DEF_BUFF, 2, 1, "CLERIC")
	target.add_status(buff)
	return "%s が %s に加護を与えた！HP+%d, DEFバフ付与。" % [cleric.char_name, target.char_name, actual]
