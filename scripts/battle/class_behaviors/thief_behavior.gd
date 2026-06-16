class_name ThiefBehavior
extends RefCounted

const STEAL_SUCCESS_RATE: float = 0.6

## 盗む: attempt to steal from target enemy.
## Returns a result dict: { "success": bool, "loot_type": String, "amount": int, "item": ItemData }
static func execute_unique(thief: Character, target: EnemyInstance, rng: RandomNumberGenerator) -> Dictionary:
	if not target.enemy_data.can_be_stolen_from:
		return { "success": false, "message": "%s から盗めるものは何もない！" % target.enemy_data.enemy_name }

	if target.instance_id in thief.thief_stolen_enemy_ids:
		return { "success": false, "message": "%s からはすでに盗んだ！" % target.enemy_data.enemy_name }

	if rng.randf() > STEAL_SUCCESS_RATE:
		return { "success": false, "message": "%s の盗みは失敗した…" % thief.char_name }

	thief.thief_stolen_enemy_ids.append(target.instance_id)

	# Determine loot based on enemy tier
	var loot_roll := rng.randf()
	match target.enemy_data.tier:
		EnemyData.EnemyTier.NORMAL:
			if loot_roll < 0.7:
				var gold := rng.randi_range(3, 8)
				return { "success": true, "loot_type": "gold", "amount": gold,
						"message": "%s がゴールド %d を盗んだ！" % [thief.char_name, gold] }
			else:
				return _steal_item(thief, rng)
		EnemyData.EnemyTier.ELITE:
			if loot_roll < 0.4:
				var gold := rng.randi_range(10, 20)
				return { "success": true, "loot_type": "gold", "amount": gold,
						"message": "%s がゴールド %d を盗んだ！" % [thief.char_name, gold] }
			elif loot_roll < 0.8:
				return _steal_item(thief, rng)
			else:
				return { "success": true, "loot_type": "special_item", "amount": 0,
						"message": "%s が特殊アイテムを盗んだ！" % thief.char_name }
		EnemyData.EnemyTier.BOSS:
			return { "success": true, "loot_type": "special_item", "amount": 0,
					"message": "%s がボスから特殊アイテムを盗んだ！" % thief.char_name }
	return { "success": false, "message": "不明なエラー" }

static func _steal_item(_thief: Character, _rng: RandomNumberGenerator) -> Dictionary:
	# Placeholder: item pool populated by SkillDatabase/ItemDatabase at runtime
	return { "success": true, "loot_type": "item", "amount": 0,
			"message": "アイテムを盗んだ！" }

## Thief passive 電光石火: skill actions have maximum speed priority.
## Called by BattleManager when sorting turn order.
static func get_skill_speed_priority() -> int:
	return 9999
