class_name StatusEffect
extends RefCounted

enum EffectType {
	ATK_BUFF,           # stackable ATK multiplier bonus
	ATK_DEBUFF,
	DEF_BUFF,
	DEF_DEBUFF,
	TAUNT,              # increased chance of being targeted by enemies
	STEALTH,            # cannot be targeted; broken on attack
	COUNTER_STANCE,     # auto-counter on being hit (0.6x damage)
	STUN,               # skip next turn
	REGEN,              # heal HP each turn
	POISON,             # lose HP each turn
	CASTING_MOMENTUM,   # Mage: ATK buff while active
	SHIELD,             # absorb next instance of damage
	COVER_ACTIVE,       # character is covering an ally (takes their hits)
	FOCUS_AIM,          # Archer: increases damage to focused target (stacks separate)
}

var effect_type: EffectType
## Stack count for stackable effects (ATK_BUFF, REGEN, etc.).
var stacks: int = 1
## Remaining turns. -1 = until condition (e.g. stealth breaks on attack).
var duration: int = 2
## Which class created this effect (for display and special interactions).
var source_class: String = ""
## Extra value (e.g. heal amount per turn for REGEN, damage for POISON).
var value: float = 0.0

func _init(type: EffectType, dur: int = 2, stack: int = 1, src: String = "", val: float = 0.0) -> void:
	effect_type = type
	duration = dur
	stacks = stack
	source_class = src
	value = val

## Returns true if the effect has expired after ticking.
func tick() -> bool:
	if duration == -1:
		return false
	duration -= 1
	return duration <= 0

func get_atk_multiplier() -> float:
	match effect_type:
		EffectType.ATK_BUFF:
			return 1.0 + stacks * 0.15
		EffectType.ATK_DEBUFF:
			return 1.0 - stacks * 0.15
		EffectType.CASTING_MOMENTUM:
			return 1.3
		_:
			return 1.0

func get_def_multiplier() -> float:
	match effect_type:
		EffectType.DEF_BUFF:
			return 1.0 + stacks * 0.15
		EffectType.DEF_DEBUFF:
			return 1.0 - stacks * 0.15
		_:
			return 1.0

func get_display_name() -> String:
	match effect_type:
		EffectType.ATK_BUFF: return "ATKバフ x%d" % stacks
		EffectType.ATK_DEBUFF: return "ATKデバフ x%d" % stacks
		EffectType.DEF_BUFF: return "DEFバフ x%d" % stacks
		EffectType.DEF_DEBUFF: return "DEFデバフ x%d" % stacks
		EffectType.TAUNT: return "挑発"
		EffectType.STEALTH: return "隠密"
		EffectType.COUNTER_STANCE: return "反撃の構え"
		EffectType.STUN: return "スタン"
		EffectType.REGEN: return "リジェネ"
		EffectType.POISON: return "毒"
		EffectType.CASTING_MOMENTUM: return "詠唱慣性"
		EffectType.SHIELD: return "シールド"
		EffectType.COVER_ACTIVE: return "かばう中"
		EffectType.FOCUS_AIM: return "照準 x%d" % stacks
		_: return "不明"
