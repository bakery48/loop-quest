class_name MonkBehavior
extends RefCounted

const STANCE_NAMES: Array[String] = ["攻撃型", "防御型", "気功型"]

## 型変え: cycle to the next stance.
static func execute_unique(monk: Character) -> String:
	monk.monk_stance = (monk.monk_stance + 1) % 3
	return "%s は%sに切り替えた！" % [monk.char_name, STANCE_NAMES[monk.monk_stance]]

## Called when monk takes damage in defense stance.
static func on_being_hit_defense_stance(monk: Character) -> String:
	if monk.monk_stance != 1:
		return ""
	monk.monk_ki = mini(monk.monk_ki + 1, 10)
	return "%s が気を蓄えた！（気: %d）" % [monk.char_name, monk.monk_ki]

## Returns ATK multiplier bonus from attack stance (applied in Character.get_effective_atk).
static func get_stance_label(monk: Character) -> String:
	return STANCE_NAMES[monk.monk_stance]
