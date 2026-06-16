class_name SkillData
extends Resource

enum Rarity { COMMON, RARE, LEGENDARY }

enum EffectType {
	DAMAGE_SINGLE,
	DAMAGE_ALL,
	DAMAGE_SINGLE_CONDITIONAL,  # requires a special_tag condition
	HEAL_SINGLE,
	HEAL_ALL,
	BUFF_ATK,
	BUFF_DEF,
	BUFF_SHIELD,       # absorb next hit
	DEBUFF_DEF,
	STATUS_TAUNT,
	STATUS_STEALTH,
	STATUS_COUNTER,
	COVER_ALLY,        # take damage for ally
	RESTORE_MP,
	SPECIAL,           # handled via special_tag in BattleManager
}

@export var skill_name: String = ""
@export var description: String = ""
@export var mp_cost: int = 0
@export var rarity: Rarity = Rarity.COMMON
## Empty array means any class can equip this skill.
@export var allowed_classes: Array[String] = []
@export var effect_type: EffectType = EffectType.DAMAGE_SINGLE
## Multiplier for damage/heal relative to stat (e.g. 1.4 = 140% ATK).
@export var power: float = 1.0
## Duration in turns for buffs/debuffs. 0 = instant.
@export var duration: int = 2
## Tag for special conditional logic (e.g. "requires_stealth_and_mage_buff", "requires_focus_3", "consumes_warrior_stacks", "consumes_ki", "double_prophecy").
@export var special_tag: String = ""
## Whether this is a magic skill (affects Mage's casting momentum passive).
@export var is_magic: bool = false
