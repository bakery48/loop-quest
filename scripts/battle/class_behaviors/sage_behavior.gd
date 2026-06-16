class_name SageBehavior
extends RefCounted

## 予言: store a skill to fire as an extra first action next turn.
## MP is consumed now. Returns error string or "" on success.
static func execute_unique(sage: Character, skill: SkillData) -> String:
	if sage.sage_prophecy_skill != null:
		return "すでに予言が仕込まれている！"
	if not sage.spend_mp(skill.mp_cost):
		return "MPが足りない！"
	sage.sage_prophecy_skill = skill
	return "%s が「%s」を予言した。次ターン先制発動！" % [sage.char_name, skill.skill_name]

## 千里眼: reveal next action of all enemies (called at round start).
## Stores telegraphed_action on each EnemyInstance so UI can display it.
static func apply_passive_foresight(sage: Character, enemies: Array[EnemyInstance]) -> String:
	if sage.class_data.class_type != ClassData.ClassType.SAGE:
		return ""
	for enemy in enemies:
		if enemy is EnemyInstance and enemy.is_alive():
			enemy.telegraphed_action = enemy.choose_next_action()
	return "%s の千里眼で敵の行動が見えた！" % sage.char_name

## Returns true if a prophecy is ready to fire. Called at round start before normal turns.
static func has_prophecy(sage: Character) -> bool:
	return sage.sage_prophecy_skill != null

## Returns the stored skill and clears it. BattleManager executes it as extra action.
static func consume_prophecy(sage: Character) -> SkillData:
	var skill := sage.sage_prophecy_skill
	sage.sage_prophecy_skill = null
	return skill
