class_name MageBehavior
extends RefCounted

const SILENTCAST_MP_RESTORE: int = 10

## 静詠: maintain casting momentum without using a skill, restore small MP.
static func execute_unique(mage: Character) -> String:
	mage.mage_used_magic_last_turn = true
	mage.restore_mp(SILENTCAST_MP_RESTORE)
	return "%s は静かに詠唱を維持した。（MP+%d）" % [mage.char_name, SILENTCAST_MP_RESTORE]

## Called at turn start (passive 詠唱慣性).
## Applies or removes CASTING_MOMENTUM, then resets the flag for this turn.
static func apply_passive_on_turn_start(mage: Character) -> String:
	var msg := ""
	if mage.mage_used_magic_last_turn:
		if not mage.has_status(StatusEffect.EffectType.CASTING_MOMENTUM):
			var momentum := StatusEffect.new(StatusEffect.EffectType.CASTING_MOMENTUM, -1, 1, "MAGE")
			mage.add_status(momentum)
			msg = "%s の詠唱慣性が発動！ATKが上昇する。" % mage.char_name
	else:
		if mage.has_status(StatusEffect.EffectType.CASTING_MOMENTUM):
			mage.remove_status_by_type(StatusEffect.EffectType.CASTING_MOMENTUM)
			msg = "%s の詠唱慣性が途切れた。" % mage.char_name
	# Flag will be set to true if skill is used this turn (BattleManager sets it)
	mage.mage_used_magic_last_turn = false
	return msg

## Called by BattleManager when a magic skill is successfully used.
static func on_magic_skill_used(mage: Character) -> void:
	mage.mage_used_magic_last_turn = true
