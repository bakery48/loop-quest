class_name BattleManager
extends Node

enum BattleState {
	IDLE,
	SETUP,
	ROUND_START,
	CALCULATING_ORDER,
	AWAITING_PLAYER_INPUT,
	EXECUTING_ACTION,
	ENEMY_TURN,
	ROUND_END,
	CHECKING_VICTORY,
	SKILL_REWARD,
	VICTORY,
	DEFEAT,
}

# ── Signals ──────────────────────────────────────────────────
signal battle_started(party: Array, enemies: Array)
signal round_started(round_num: int)
signal log_message(text: String)
signal player_input_needed(character: Character, available_commands: Array)
## Emitted when player must choose a skill from skill_slots.
signal skill_menu_needed(character: Character, skills: Array)
## Emitted when player must choose an item from inventory.
signal item_menu_needed(character: Character, items: Array)
## Emitted when player must choose an ally target.
signal ally_target_needed(character: Character, allies: Array)
## Emitted when player must choose an enemy target.
signal enemy_target_needed(character: Character, enemies: Array)
## Emitted when enemy's next action has been telegraphed (Sage passive).
signal enemy_telegraphed(enemy: EnemyInstance, action: EnemyAction)
## Emitted when the prophecy fires as an extra first action.
signal prophecy_fired(sage: Character, skill: SkillData)
## Emitted after victory; UI should show skill pick.
signal skill_reward_available(skills: Array)
signal battle_ended(victory: bool, gold_earned: int)
signal turn_changed(actor_name: String, is_player_turn: bool)

# ── State ─────────────────────────────────────────────────────
var state: BattleState = BattleState.IDLE
var party: Array[Character] = []
var enemies: Array[EnemyInstance] = []
## Ordered list of (Character | EnemyInstance) for the current round.
var turn_order: Array = []
var current_turn_index: int = 0
var round_number: int = 0
var is_elite_battle: bool = false
var rng: RandomNumberGenerator

## Tracks pending input type so submit_player_action knows what context we're in.
enum InputContext { COMMAND, SKILL_SELECT, ITEM_SELECT, ALLY_TARGET, ENEMY_TARGET, PROPHECY_SKILL }
var _pending_context: InputContext = InputContext.COMMAND
var _pending_actor: Character = null
var _pending_command: String = ""
var _pending_skill: SkillData = null

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()

# ── Public API ────────────────────────────────────────────────

func setup_battle(party_members: Array[Character], enemy_list: Array[EnemyData], elite: bool = false) -> void:
	state = BattleState.SETUP
	party = party_members
	enemies = []
	is_elite_battle = elite
	EnemyInstance.reset_id_counter()
	for ed in enemy_list:
		enemies.append(EnemyInstance.create(ed))
	for member in party:
		member.reset_battle_state()
	battle_started.emit(party, enemies)

func start_battle() -> void:
	round_number = 0
	_begin_next_round()

## Called by the UI to submit a player decision.
## command: "fight" | "skill" | "item" | "unique"
## skill: SkillData if command=="skill", or the prophecy skill if context==PROPHECY_SKILL
## target_enemy_index: index in enemies array (-1 if no enemy target)
## target_ally_index: index in party array (-1 if no ally target)
## item: ItemData if command=="item"
func submit_player_action(command: String, skill: SkillData = null,
		target_enemy_index: int = -1, target_ally_index: int = -1,
		item: ItemData = null) -> void:
	if state != BattleState.AWAITING_PLAYER_INPUT:
		return
	var actor := _pending_actor
	state = BattleState.EXECUTING_ACTION

	match command:
		"fight":
			_execute_fight(actor, target_enemy_index)
		"skill":
			_execute_skill(actor, skill, target_enemy_index, target_ally_index)
		"item":
			_execute_item(actor, item, target_enemy_index, target_ally_index)
		"unique":
			_execute_unique_command(actor, target_enemy_index, target_ally_index, skill)

	_post_action(actor)

# ── Round & Turn Flow ─────────────────────────────────────────

func _begin_next_round() -> void:
	round_number += 1
	state = BattleState.ROUND_START
	round_started.emit(round_number)

	# Hero passive: MP regen
	for member in party:
		if member.is_alive() and member.class_data.class_type == ClassData.ClassType.HERO:
			var msg := HeroBehavior.apply_passive_mp_regen(member, party)
			log_message.emit(msg)

	# Cleric passive: auto-heal lowest HP
	for member in party:
		if member.is_alive() and member.class_data.class_type == ClassData.ClassType.CLERIC:
			var msg := ClericBehavior.apply_passive_heal(member, party)
			if msg != "":
				log_message.emit(msg)

	# Sage passive 千里眼: telegraph enemy actions
	for member in party:
		if member.is_alive() and member.class_data.class_type == ClassData.ClassType.SAGE:
			var msg := SageBehavior.apply_passive_foresight(member, enemies)
			log_message.emit(msg)
			for enemy in enemies:
				if enemy.is_alive() and enemy.telegraphed_action:
					enemy_telegraphed.emit(enemy, enemy.telegraphed_action)

	# Mage passive 詠唱慣性: evaluate momentum from last turn
	for member in party:
		if member.is_alive() and member.class_data.class_type == ClassData.ClassType.MAGE:
			var msg := MageBehavior.apply_passive_on_turn_start(member)
			if msg != "":
				log_message.emit(msg)

	# Fire Sage prophecies as extra first actions
	for member in party:
		if member.is_alive() and member.class_data.class_type == ClassData.ClassType.SAGE:
			if SageBehavior.has_prophecy(member):
				var prophecy_skill := SageBehavior.consume_prophecy(member)
				log_message.emit("%s の予言が発動！「%s」先制実行！" % [member.char_name, prophecy_skill.skill_name])
				prophecy_fired.emit(member, prophecy_skill)
				_execute_skill(member, prophecy_skill, _get_random_alive_enemy_index(), -1)

	_calculate_turn_order()
	current_turn_index = 0
	_advance_turn()

func _calculate_turn_order() -> void:
	state = BattleState.CALCULATING_ORDER
	turn_order.clear()
	for member in party:
		if member.is_alive():
			turn_order.append(member)
	for enemy in enemies:
		if enemy.is_alive():
			turn_order.append(enemy)
	# Sort by effective speed descending
	turn_order.sort_custom(func(a, b):
		var spd_a := a.get_effective_spd() if a is Character else a.enemy_data.spd
		var spd_b := b.get_effective_spd() if b is Character else b.enemy_data.spd
		return spd_a > spd_b
	)

func _advance_turn() -> void:
	# Remove dead combatants from remaining turn order
	while current_turn_index < turn_order.size():
		var actor = turn_order[current_turn_index]
		var alive := actor.is_alive() if actor is Character else (actor as EnemyInstance).is_alive()
		if alive:
			break
		current_turn_index += 1

	if current_turn_index >= turn_order.size():
		_end_round()
		return

	var actor = turn_order[current_turn_index]
	if actor is Character:
		_begin_player_turn(actor)
	else:
		_begin_enemy_turn(actor as EnemyInstance)

func _end_round() -> void:
	state = BattleState.ROUND_END
	# Tick status effects
	for member in party:
		if member.is_alive():
			_apply_regen_poison(member)
			member.tick_statuses()
	for enemy in enemies:
		if enemy.is_alive():
			enemy.tick_statuses()

	if _check_battle_end():
		return
	_begin_next_round()

func _begin_player_turn(character: Character) -> void:
	state = BattleState.AWAITING_PLAYER_INPUT
	_pending_actor = character
	turn_changed.emit(character.char_name, true)
	var commands: Array[String] = ["たたかう", "スキル", "どうぐ", "固有コマンド"]
	if character.skill_slots.is_empty():
		commands.erase("スキル")
	if GameState.items.is_empty():
		commands.erase("どうぐ")
	player_input_needed.emit(character, commands)

func _post_action(actor: Character) -> void:
	if _check_battle_end():
		return
	current_turn_index += 1
	_advance_turn()

# ── Player Commands ───────────────────────────────────────────

func _execute_fight(attacker: Character, target_enemy_index: int) -> void:
	var target := _get_target_enemy(target_enemy_index)
	if target == null:
		return
	var damage := _calculate_damage(attacker.get_effective_atk(), target.get_effective_def())
	# Monk attack stance bonus
	if attacker.class_data.class_type == ClassData.ClassType.MONK and attacker.monk_stance == 0:
		damage = int(damage * 1.3)
	var actual := target.take_damage(damage)
	log_message.emit("%s が %s を攻撃！%d ダメージ！" % [attacker.char_name, target.enemy_data.enemy_name, actual])
	_on_player_dealt_damage(attacker, target, actual)
	_check_enemy_death(target)

func _execute_skill(caster: Character, skill: SkillData, target_enemy_index: int, target_ally_index: int) -> void:
	if skill == null:
		log_message.emit("スキルが選択されていない！")
		return
	if not caster.spend_mp(skill.mp_cost):
		log_message.emit("%s のMPが足りない！" % caster.char_name)
		return

	# Mage tracking
	if skill.is_magic and caster.class_data.class_type == ClassData.ClassType.MAGE:
		MageBehavior.on_magic_skill_used(caster)

	log_message.emit("%s が「%s」を使った！" % [caster.char_name, skill.skill_name])

	match skill.effect_type:
		SkillData.EffectType.DAMAGE_SINGLE:
			var target := _get_target_enemy(target_enemy_index)
			if target:
				var dmg := _calculate_damage(int(caster.get_effective_atk() * skill.power), target.get_effective_def())
				var actual := target.take_damage(dmg)
				log_message.emit("→ %s に %d ダメージ！" % [target.enemy_data.enemy_name, actual])
				_on_player_dealt_damage(caster, target, actual)
				_check_enemy_death(target)

		SkillData.EffectType.DAMAGE_ALL:
			for enemy in enemies:
				if enemy.is_alive():
					var dmg := _calculate_damage(int(caster.get_effective_atk() * skill.power), enemy.get_effective_def())
					var actual := enemy.take_damage(dmg)
					log_message.emit("→ %s に %d ダメージ！" % [enemy.enemy_data.enemy_name, actual])
					_check_enemy_death(enemy)

		SkillData.EffectType.HEAL_SINGLE:
			var target_ally := _get_target_ally(target_ally_index)
			if target_ally:
				var amount := int(caster.base_atk * skill.power)
				var actual := target_ally.heal(amount)
				log_message.emit("→ %s のHP+%d！" % [target_ally.char_name, actual])

		SkillData.EffectType.HEAL_ALL:
			for member in party:
				if member.is_alive():
					var amount := int(caster.base_atk * skill.power)
					var actual := member.heal(amount)
					log_message.emit("→ %s のHP+%d！" % [member.char_name, actual])

		SkillData.EffectType.BUFF_ATK:
			var t := _get_target_ally(target_ally_index) if target_ally_index >= 0 else caster
			var buff := StatusEffect.new(StatusEffect.EffectType.ATK_BUFF, skill.duration, 1, caster.class_data.class_id)
			t.add_status(buff)
			log_message.emit("→ %s のATKが上昇！" % t.char_name)

		SkillData.EffectType.BUFF_DEF:
			var t := _get_target_ally(target_ally_index) if target_ally_index >= 0 else caster
			var buff := StatusEffect.new(StatusEffect.EffectType.DEF_BUFF, skill.duration, 1, caster.class_data.class_id)
			t.add_status(buff)
			log_message.emit("→ %s のDEFが上昇！" % t.char_name)

		SkillData.EffectType.DEBUFF_DEF:
			var target := _get_target_enemy(target_enemy_index)
			if target:
				var debuff := StatusEffect.new(StatusEffect.EffectType.DEF_DEBUFF, skill.duration, 1, caster.class_data.class_id)
				target.status_effects.append(debuff)
				log_message.emit("→ %s のDEFが低下！" % target.enemy_data.enemy_name)

		SkillData.EffectType.STATUS_TAUNT:
			var buff := StatusEffect.new(StatusEffect.EffectType.TAUNT, skill.duration, 1, caster.class_data.class_id)
			caster.add_status(buff)
			log_message.emit("→ %s が挑発した！" % caster.char_name)

		SkillData.EffectType.STATUS_STEALTH:
			var eff := StatusEffect.new(StatusEffect.EffectType.STEALTH, skill.duration, 1, caster.class_data.class_id)
			caster.add_status(eff)
			log_message.emit("→ %s が隠密状態になった！" % caster.char_name)

		SkillData.EffectType.STATUS_COUNTER:
			var eff := StatusEffect.new(StatusEffect.EffectType.COUNTER_STANCE, skill.duration, 1, caster.class_data.class_id)
			caster.add_status(eff)
			log_message.emit("→ %s が反撃の構えをとった！" % caster.char_name)

		SkillData.EffectType.COVER_ALLY:
			var t := _get_target_ally(target_ally_index)
			if t:
				var eff := StatusEffect.new(StatusEffect.EffectType.COVER_ACTIVE, 1, 1, caster.class_data.class_id)
				t.add_status(eff)
				log_message.emit("→ %s が %s をかばう！" % [caster.char_name, t.char_name])

		SkillData.EffectType.RESTORE_MP:
			var t := _get_target_ally(target_ally_index) if target_ally_index >= 0 else caster
			var amount := int(skill.power)
			var actual := t.restore_mp(amount)
			log_message.emit("→ %s のMP+%d！" % [t.char_name, actual])

		SkillData.EffectType.DAMAGE_SINGLE_CONDITIONAL:
			_execute_conditional_skill(caster, skill, target_enemy_index)

		SkillData.EffectType.SPECIAL:
			_execute_special_skill(caster, skill, target_enemy_index, target_ally_index)

func _execute_conditional_skill(caster: Character, skill: SkillData, target_enemy_index: int) -> void:
	var target := _get_target_enemy(target_enemy_index)
	if target == null:
		return

	match skill.special_tag:
		"requires_stealth_and_mage_buff":
			# 影斬り: requires caster stealth + a Mage in party has casting momentum
			var has_stealth := caster.has_status(StatusEffect.EffectType.STEALTH)
			var mage_buffed := false
			for member in party:
				if member.class_data.class_type == ClassData.ClassType.MAGE:
					if member.has_status(StatusEffect.EffectType.CASTING_MOMENTUM):
						mage_buffed = true
			if not has_stealth or not mage_buffed:
				log_message.emit("発動条件を満たしていない！（隠密 + 魔法使いATKバフが必要）")
				return
			caster.remove_status_by_type(StatusEffect.EffectType.STEALTH)
			var dmg := _calculate_damage(int(caster.get_effective_atk() * skill.power), target.get_effective_def())
			var actual := target.take_damage(dmg)
			log_message.emit("→ 条件達成！%s に %d ダメージ + デバフ！" % [target.enemy_data.enemy_name, actual])
			var debuff := StatusEffect.new(StatusEffect.EffectType.DEF_DEBUFF, 2, 2, caster.class_data.class_id)
			target.status_effects.append(debuff)
			_check_enemy_death(target)

		"requires_focus_3":
			# 貫通矢: requires archer_focus_stacks >= 3
			if caster.archer_focus_stacks < 3:
				log_message.emit("照準精度が足りない！（3以上必要）")
				return
			caster.archer_focus_stacks = 0
			for enemy in enemies:
				if enemy.is_alive():
					var dmg := _calculate_damage(int(caster.get_effective_atk() * skill.power), enemy.get_effective_def())
					var actual := enemy.take_damage(dmg)
					log_message.emit("→ %s に %d ダメージ（貫通）！" % [enemy.enemy_data.enemy_name, actual])
					_check_enemy_death(enemy)

		"consumes_warrior_stacks":
			# 怒りの爆発: damage scales with warrior ATK stacks, then consumes them
			if caster.warrior_atk_stacks == 0:
				log_message.emit("ATKバフスタックがない！")
				return
			var bonus_mult := 1.0 + caster.warrior_atk_stacks * 0.5
			caster.warrior_atk_stacks = 0
			var dmg := _calculate_damage(int(caster.get_effective_atk() * skill.power * bonus_mult), target.get_effective_def())
			var actual := target.take_damage(dmg)
			log_message.emit("→ 怒りを解放！%s に %d ダメージ！" % [target.enemy_data.enemy_name, actual])
			_check_enemy_death(target)

		"consumes_ki":
			# 覇王拳: consume all monk ki, ki amount × multiplier damage
			if caster.monk_ki == 0:
				log_message.emit("気ゲージがない！")
				return
			var ki_count := caster.monk_ki
			caster.monk_ki = 0
			var dmg := _calculate_damage(int(caster.get_effective_atk() * skill.power * ki_count), target.get_effective_def())
			var actual := target.take_damage(dmg)
			log_message.emit("→ 覇王拳！気%d消費、%s に %d ダメージ + スタン！" % [ki_count, target.enemy_data.enemy_name, actual])
			target.status_effects.append(StatusEffect.new(StatusEffect.EffectType.STUN, 1))
			_check_enemy_death(target)

func _execute_special_skill(_caster: Character, skill: SkillData, _t_enemy: int, _t_ally: int) -> void:
	match skill.special_tag:
		"double_prophecy":
			log_message.emit("二重予言はまだ実装されていません。")
		_:
			log_message.emit("特殊スキル「%s」: %s" % [skill.skill_name, skill.description])

func _execute_item(actor: Character, item: ItemData, _t_enemy: int, target_ally_index: int) -> void:
	if item == null:
		return
	GameState.items.erase(item)
	match item.item_type:
		ItemData.ItemType.HEAL_HP:
			var target := _get_target_ally(target_ally_index) if target_ally_index >= 0 else actor
			var actual := target.heal(int(item.power))
			log_message.emit("%s が「%s」を使った！%s のHP+%d。" % [actor.char_name, item.item_name, target.char_name, actual])
		ItemData.ItemType.HEAL_MP:
			var target := _get_target_ally(target_ally_index) if target_ally_index >= 0 else actor
			var actual := target.restore_mp(int(item.power))
			log_message.emit("%s が「%s」を使った！%s のMP+%d。" % [actor.char_name, item.item_name, target.char_name, actual])
		ItemData.ItemType.BUFF_ATK_TEMP:
			var target := _get_target_ally(target_ally_index) if target_ally_index >= 0 else actor
			var buff := StatusEffect.new(StatusEffect.EffectType.ATK_BUFF, item.duration, 1, "ITEM")
			target.add_status(buff)
			log_message.emit("%s が「%s」を使った！%s のATK上昇。" % [actor.char_name, item.item_name, target.char_name])
		ItemData.ItemType.BUFF_DEF_TEMP:
			var target := _get_target_ally(target_ally_index) if target_ally_index >= 0 else actor
			var buff := StatusEffect.new(StatusEffect.EffectType.DEF_BUFF, item.duration, 1, "ITEM")
			target.add_status(buff)
			log_message.emit("%s が「%s」を使った！%s のDEF上昇。" % [actor.char_name, item.item_name, target.char_name])

func _execute_unique_command(actor: Character, target_enemy_index: int, target_ally_index: int, extra: SkillData) -> void:
	match actor.class_data.class_type:
		ClassData.ClassType.WARRIOR:
			var msg := WarriorBehavior.execute_unique(actor)
			log_message.emit(msg)

		ClassData.ClassType.MAGE:
			var msg := MageBehavior.execute_unique(actor)
			log_message.emit(msg)

		ClassData.ClassType.CLERIC:
			var target := _get_target_ally(target_ally_index)
			if target:
				var msg := ClericBehavior.execute_unique(actor, target)
				log_message.emit(msg)

		ClassData.ClassType.THIEF:
			var enemy := _get_target_enemy(target_enemy_index)
			if enemy:
				var result := ThiefBehavior.execute_unique(actor, enemy, rng)
				log_message.emit(result.get("message", ""))
				if result.get("success", false):
					if result.get("loot_type", "") == "gold":
						GameState.collect_gold(result.get("amount", 0))

		ClassData.ClassType.ARCHER:
			var enemy := _get_target_enemy(target_enemy_index)
			if enemy:
				if actor.archer_focus_target_id != enemy.instance_id:
					actor.archer_focus_stacks = 0
					actor.archer_focus_target_id = enemy.instance_id
					log_message.emit("%s が %s に照準を合わせた！精度リセット。" % [actor.char_name, enemy.enemy_data.enemy_name])
				else:
					log_message.emit("%s が照準を維持。（標的: %s）" % [actor.char_name, enemy.enemy_data.enemy_name])

		ClassData.ClassType.MONK:
			var msg := MonkBehavior.execute_unique(actor)
			log_message.emit(msg)

		ClassData.ClassType.SAGE:
			if extra:
				var msg := SageBehavior.execute_unique(actor, extra)
				log_message.emit(msg)

		ClassData.ClassType.HERO:
			var target := _get_target_ally(target_ally_index)
			if target:
				var msg := HeroBehavior.execute_unique(actor, target)
				log_message.emit(msg)
				# Insert target after current in turn_order for extra action
				turn_order.insert(current_turn_index + 1, target)

		ClassData.ClassType.ALCHEMIST:
			log_message.emit("%s が調合！（未実装）" % actor.char_name)

		ClassData.ClassType.SUMMONER:
			log_message.emit("%s が召喚！（未実装）" % actor.char_name)

# ── Enemy Turn ────────────────────────────────────────────────

func _begin_enemy_turn(enemy: EnemyInstance) -> void:
	state = BattleState.ENEMY_TURN
	turn_changed.emit(enemy.enemy_data.enemy_name, false)

	if enemy.telegraphed_action:
		var action := enemy.telegraphed_action
		enemy.telegraphed_action = null
		_execute_enemy_action(enemy, action)
	else:
		var action := enemy.choose_next_action()
		if action:
			_execute_enemy_action(enemy, action)

	if _check_battle_end():
		return
	current_turn_index += 1
	_advance_turn()

func _execute_enemy_action(enemy: EnemyInstance, action: EnemyAction) -> void:
	match action.action_type:
		EnemyAction.ActionType.ATTACK_SINGLE:
			var target := _choose_enemy_attack_target()
			if target == null:
				return
			# Check if target has cover
			var covered_by := _find_cover_guardian(target)
			var actual_target := covered_by if covered_by else target
			var dmg := _calculate_damage(int(enemy.get_effective_atk() * action.power), actual_target.get_effective_def())
			# Monk defense stance -30%
			if actual_target.class_data.class_type == ClassData.ClassType.MONK and actual_target.monk_stance == 1:
				dmg = int(dmg * 0.7)
			var actual := actual_target.take_damage(dmg)
			log_message.emit("%s が %s を攻撃！%d ダメージ！" % [enemy.enemy_data.enemy_name, actual_target.char_name, actual])
			# Break stealth on target
			if actual_target.has_status(StatusEffect.EffectType.STEALTH):
				actual_target.remove_status_by_type(StatusEffect.EffectType.STEALTH)
			# Warrior/Monk passive on being hit
			_on_character_hit_by_enemy(actual_target, actual)
			# Counter-attack
			if actual_target.has_status(StatusEffect.EffectType.COUNTER_STANCE) and actual_target.is_alive():
				var counter_dmg := _calculate_damage(int(actual_target.get_effective_atk() * 0.6), enemy.get_effective_def())
				var c_actual := enemy.take_damage(counter_dmg)
				log_message.emit("→ %s が反撃！%d ダメージ！" % [actual_target.char_name, c_actual])
				_check_enemy_death(enemy)

		EnemyAction.ActionType.ATTACK_ALL:
			for member in party:
				if member.is_alive():
					var dmg := _calculate_damage(int(enemy.get_effective_atk() * action.power), member.get_effective_def())
					var actual := member.take_damage(dmg)
					log_message.emit("%s の全体攻撃！%s に %d ダメージ！" % [enemy.enemy_data.enemy_name, member.char_name, actual])
					_on_character_hit_by_enemy(member, actual)

		EnemyAction.ActionType.BUFF_SELF_ATK:
			var buff := StatusEffect.new(StatusEffect.EffectType.ATK_BUFF, action.duration, 1, "ENEMY")
			enemy.status_effects.append(buff)
			log_message.emit("%s のATKが上昇！" % enemy.enemy_data.enemy_name)

		EnemyAction.ActionType.BUFF_SELF_DEF:
			var buff := StatusEffect.new(StatusEffect.EffectType.DEF_BUFF, action.duration, 1, "ENEMY")
			enemy.status_effects.append(buff)
			log_message.emit("%s のDEFが上昇！" % enemy.enemy_data.enemy_name)

		EnemyAction.ActionType.DEBUFF_TARGET_DEF:
			var target := _choose_enemy_attack_target()
			if target:
				var debuff := StatusEffect.new(StatusEffect.EffectType.DEF_DEBUFF, action.duration, 1, "ENEMY")
				target.add_status(debuff)
				log_message.emit("%s が %s のDEFを下げた！" % [enemy.enemy_data.enemy_name, target.char_name])

		EnemyAction.ActionType.HEAL_SELF:
			var heal_amount := int(enemy.enemy_data.max_hp * action.power)
			var actual := enemy.heal(heal_amount)
			log_message.emit("%s がHP%dを回復した！" % [enemy.enemy_data.enemy_name, actual])

		EnemyAction.ActionType.APPLY_POISON:
			var target := _choose_enemy_attack_target()
			if target:
				var poison := StatusEffect.new(
					StatusEffect.EffectType.POISON, action.duration, 1, "ENEMY",
					float(enemy.enemy_data.atk) * action.power * 0.4)
				target.add_status(poison)
				log_message.emit("%s が %s に毒を与えた！" % [enemy.enemy_data.enemy_name, target.char_name])

	# Announce enrage if it just triggered
	if enemy.is_alive() and enemy.is_enraged:
		var has_rage_log := false
		for eff in enemy.status_effects:
			if eff.source_class == "ENRAGE" and eff.stacks == 2:
				has_rage_log = true
		if has_rage_log:
			# Only log once (when newly enraged this action)
			pass  # Enrage log is emitted from _check_enemy_enrage

# ── Helpers ───────────────────────────────────────────────────

func _calculate_damage(raw_atk: int, raw_def: int) -> int:
	return max(1, raw_atk - raw_def)

func _on_player_dealt_damage(_attacker: Character, _target: EnemyInstance, _damage: int) -> void:
	# Archer: if attacking focused target, increment stacks
	if _attacker.class_data.class_type == ClassData.ClassType.ARCHER:
		if _attacker.archer_focus_target_id == _target.instance_id:
			_attacker.archer_focus_stacks = mini(_attacker.archer_focus_stacks + 1, Character.MAX_ARCHER_STACKS)
			log_message.emit("照準精度が上昇！（%d段）" % _attacker.archer_focus_stacks)

func _on_character_hit_by_enemy(character: Character, _damage: int) -> void:
	if character.class_data.class_type == ClassData.ClassType.WARRIOR:
		var msg := WarriorBehavior.on_being_hit(character)
		if msg != "":
			log_message.emit(msg)
	if character.class_data.class_type == ClassData.ClassType.MONK:
		var msg := MonkBehavior.on_being_hit_defense_stance(character)
		if msg != "":
			log_message.emit(msg)

func _apply_regen_poison(member: Character) -> void:
	for effect in member.status_effects:
		match effect.effect_type:
			StatusEffect.EffectType.REGEN:
				var h := member.heal(int(effect.value))
				log_message.emit("%s がリジェネで HP+%d。" % [member.char_name, h])
			StatusEffect.EffectType.POISON:
				var dmg: int = maxi(1, int(effect.value))
				member.current_hp = maxi(0, member.current_hp - dmg)
				member.hp_changed.emit(member.current_hp, member.max_hp)
				log_message.emit("%s が毒で HP-%d。" % [member.char_name, dmg])
				if member.current_hp == 0:
					member.died.emit()

func _choose_enemy_attack_target() -> Character:
	# Prefer taunted character
	for member in party:
		if member.is_alive() and member.has_status(StatusEffect.EffectType.TAUNT):
			return member
	# Otherwise random alive
	var alive_party: Array[Character] = []
	for member in party:
		if member.is_alive() and not member.has_status(StatusEffect.EffectType.STEALTH):
			alive_party.append(member)
	if alive_party.is_empty():
		# All stealthed or dead — pick any alive
		for member in party:
			if member.is_alive():
				return member
		return null
	return alive_party[rng.randi() % alive_party.size()]

func _find_cover_guardian(target: Character) -> Character:
	for member in party:
		if member.is_alive() and member != target:
			if member.has_status(StatusEffect.EffectType.COVER_ACTIVE):
				var eff := member.get_status(StatusEffect.EffectType.COVER_ACTIVE)
				member.remove_status_by_type(StatusEffect.EffectType.COVER_ACTIVE)
				return member
	return null

func _get_target_enemy(index: int) -> EnemyInstance:
	if index < 0 or index >= enemies.size():
		return null
	if not enemies[index].is_alive():
		return null
	return enemies[index]

func _get_target_ally(index: int) -> Character:
	if index < 0 or index >= party.size():
		return null
	if not party[index].is_alive():
		return null
	return party[index]

func _get_random_alive_enemy_index() -> int:
	var alive: Array[int] = []
	for i in range(enemies.size()):
		if enemies[i].is_alive():
			alive.append(i)
	if alive.is_empty():
		return -1
	return alive[rng.randi() % alive.size()]

func _check_enemy_death(enemy: EnemyInstance) -> void:
	if enemy.is_alive():
		# Log enrage if it just triggered this hit
		if enemy.is_enraged:
			for eff in enemy.status_effects:
				if eff.source_class == "ENRAGE":
					log_message.emit("⚠ %s が怒り狂った！ATKが大幅上昇！" % enemy.enemy_data.enemy_name)
					eff.source_class = "ENRAGE_LOGGED"  # prevent repeat
					break
		return
	log_message.emit("%s を倒した！" % enemy.enemy_data.enemy_name)
	# Alchemist passive: collect material
	for member in party:
		if member.is_alive() and member.class_data.class_type == ClassData.ClassType.ALCHEMIST:
			if member.alchemist_materials.size() < Character.MAX_ALCHEMIST_MATERIALS:
				log_message.emit("%s が素材を入手した！" % member.char_name)

func _check_battle_end() -> bool:
	var all_enemies_dead := true
	for enemy in enemies:
		if enemy.is_alive():
			all_enemies_dead = false
			break

	if all_enemies_dead:
		_on_victory()
		return true

	var all_party_dead := true
	for member in party:
		if member.is_alive():
			all_party_dead = false
			break

	if all_party_dead:
		_on_defeat()
		return true

	return false

func _on_victory() -> void:
	state = BattleState.VICTORY
	var gold := 0
	for enemy in enemies:
		gold += rng.randi_range(enemy.enemy_data.gold_min, enemy.enemy_data.gold_max)
	GameState.collect_gold(gold)
	log_message.emit("✨ 勝利！ゴールド %d 獲得！" % gold)
	var rewards := _generate_skill_rewards()
	state = BattleState.SKILL_REWARD
	skill_reward_available.emit(rewards)
	battle_ended.emit(true, gold)

func _on_defeat() -> void:
	state = BattleState.DEFEAT
	log_message.emit("全滅…")
	battle_ended.emit(false, 0)

func _generate_skill_rewards() -> Array:
	return SkillDatabase.get_random_skill_rewards(3, is_elite_battle, _get_party_class_ids())

func _get_party_class_ids() -> Array[String]:
	var ids: Array[String] = []
	for member in party:
		ids.append(member.class_data.class_id)
	return ids
