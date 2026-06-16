class_name HeroBehavior
extends RefCounted

const PASSIVE_MP_RESTORE: int = 5

## 鼓舞のオーラ: restore MP to all party members at the start of each turn.
## Called by BattleManager at round start.
static func apply_passive_mp_regen(hero: Character, party: Array[Character]) -> String:
	var msg := ""
	for member in party:
		if member is Character and member.is_alive():
			var restored := member.restore_mp(PASSIVE_MP_RESTORE)
			if restored > 0:
				msg += "%s のMP+%d。" % [member.char_name, restored]
	return "%s の鼓舞のオーラ！" % hero.char_name + msg

## 連携: grant an ally an extra action this turn.
## BattleManager inserts target into the turn order immediately after current actor.
static func execute_unique(hero: Character, target: Character) -> String:
	return "%s が %s に連携を付与！追加行動が発生する。" % [hero.char_name, target.char_name]
