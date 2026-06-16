extends Control

@onready var enemy_area: HBoxContainer = $VBox/EnemyArea
@onready var party_area: HBoxContainer = $VBox/PartyArea
@onready var action_log: RichTextLabel = $VBox/ActionLog
@onready var actor_label: Label = $VBox/CommandPanel/ActorLabel
@onready var fight_btn: Button = $VBox/CommandPanel/CommandButtons/FightBtn
@onready var skill_btn: Button = $VBox/CommandPanel/CommandButtons/SkillBtn
@onready var item_btn: Button = $VBox/CommandPanel/CommandButtons/ItemBtn
@onready var unique_btn: Button = $VBox/CommandPanel/CommandButtons/UniqueBtn
@onready var sub_menu: VBoxContainer = $VBox/CommandPanel/SubMenu

var _battle_manager: BattleManager
var _current_character: Character = null
var _selected_skill: SkillData = null
var _pending_command: String = ""
var _skill_overlay: SkillRewardOverlay = null

## Which type of target selection we're waiting for.
enum SelectMode { NONE, ENEMY, ALLY }
var _select_mode: SelectMode = SelectMode.NONE

func _ready() -> void:
	_setup_battle_manager()
	_connect_buttons()
	_set_commands_enabled(false)
	_start_battle()

func _setup_battle_manager() -> void:
	_battle_manager = BattleManager.new()
	$BattleManager.add_child(_battle_manager)

	_battle_manager.log_message.connect(_log)
	_battle_manager.player_input_needed.connect(_on_player_input_needed)
	_battle_manager.turn_changed.connect(_on_turn_changed)
	_battle_manager.battle_ended.connect(_on_battle_ended)
	_battle_manager.skill_reward_available.connect(_on_skill_reward)
	_battle_manager.enemy_telegraphed.connect(_on_enemy_telegraphed)

func _connect_buttons() -> void:
	fight_btn.pressed.connect(_on_fight_pressed)
	skill_btn.pressed.connect(_on_skill_pressed)
	item_btn.pressed.connect(_on_item_pressed)
	unique_btn.pressed.connect(_on_unique_pressed)

var _is_boss_battle: bool = false

func _start_battle() -> void:
	var node := GameState.get_current_node()
	var is_elite := node != null and node.node_type == MapNodeData.NodeType.ELITE
	_is_boss_battle = node != null and node.node_type == MapNodeData.NodeType.BOSS

	var enemy_data_list := EnemyDatabase.get_encounter(
		GameState.current_chapter, is_elite, _is_boss_battle, GameState.run_rng)
	_battle_manager.setup_battle(GameState.party, enemy_data_list, is_elite)
	_build_enemy_area()
	_build_party_area()

	# Show boss intro message
	if _is_boss_battle and not enemy_data_list.is_empty():
		var intro: String = enemy_data_list[0].boss_intro_message
		if intro != "":
			_log("⚔ " + intro)

	_battle_manager.start_battle()

# ── UI Builders ───────────────────────────────────────────────

var _enemy_hp_labels: Array[Label] = []
var _party_hp_labels: Array[Label] = []

func _build_enemy_area() -> void:
	for c in enemy_area.get_children():
		c.queue_free()
	_enemy_hp_labels.clear()
	for i in range(_battle_manager.enemies.size()):
		var enemy := _battle_manager.enemies[i]
		var vbox := VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(180, 0)

		var name_lbl := Label.new()
		var tier_icon := ""
		match enemy.enemy_data.tier:
			EnemyData.EnemyTier.ELITE: tier_icon = "⚡"
			EnemyData.EnemyTier.BOSS: tier_icon = "👑"
		name_lbl.text = "%s%s" % [tier_icon, enemy.enemy_data.enemy_name]

		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d/%d" % [enemy.current_hp, enemy.enemy_data.max_hp]
		_enemy_hp_labels.append(hp_lbl)

		var status_lbl := Label.new()
		status_lbl.text = ""

		enemy.hp_changed.connect(func(hp, max_hp):
			hp_lbl.text = "HP: %d/%d" % [hp, max_hp]
			# Update status display
			var statuses: Array[String] = []
			for eff in enemy.status_effects:
				statuses.append(eff.get_display_name())
			status_lbl.text = " ".join(statuses)
			if enemy.is_enraged:
				name_lbl.modulate = Color.RED
		)

		vbox.add_child(name_lbl)
		vbox.add_child(hp_lbl)
		vbox.add_child(status_lbl)
		enemy_area.add_child(vbox)

func _build_party_area() -> void:
	for c in party_area.get_children():
		c.queue_free()
	_party_hp_labels.clear()
	for member in _battle_manager.party:
		var vbox := VBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = "[%s]" % member.char_name
		var hp_lbl := Label.new()
		hp_lbl.text = "HP:%d/%d MP:%d/%d" % [member.current_hp, member.max_hp, member.current_mp, member.max_mp]
		_party_hp_labels.append(hp_lbl)
		member.hp_changed.connect(func(_hp, _mhp): _refresh_party_labels())
		member.mp_changed.connect(func(_mp, _mmp): _refresh_party_labels())
		vbox.add_child(name_lbl)
		vbox.add_child(hp_lbl)
		party_area.add_child(vbox)

func _refresh_party_labels() -> void:
	var i := 0
	for member in _battle_manager.party:
		if i < _party_hp_labels.size():
			_party_hp_labels[i].text = "HP:%d/%d MP:%d/%d" % [member.current_hp, member.max_hp, member.current_mp, member.max_mp]
		i += 1

# ── Battle Events ─────────────────────────────────────────────

func _log(text: String) -> void:
	action_log.append_text("\n" + text)

func _on_turn_changed(actor_name: String, is_player: bool) -> void:
	if is_player:
		actor_label.text = "▶ %s のターン" % actor_name
	else:
		actor_label.text = "敵のターン: %s" % actor_name

func _on_player_input_needed(character: Character, _commands: Array) -> void:
	_current_character = character
	_set_commands_enabled(true)
	unique_btn.text = character.class_data.unique_command_name
	_clear_sub_menu()

func _on_battle_ended(victory: bool, _gold: int) -> void:
	_set_commands_enabled(false)
	if not victory:
		_log("\n💀 全滅…")
		await get_tree().create_timer(3.0).timeout
		GameState.end_run(false)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	# Victory
	if _is_boss_battle:
		var next_chapter := GameState.current_chapter + 1
		if next_chapter > 3:
			# Final boss cleared — run complete, but still offer skill reward
			_log("\n🏆 全クリア！魔王の将軍を倒した！")
		else:
			_log("\n✨ ボス撃破！第%d章へ進む…" % next_chapter)
		# Skill reward is shown via skill_reward_available signal (already emitted)

func _on_skill_reward(skills: Array) -> void:
	_set_commands_enabled(false)
	_skill_overlay = SkillRewardOverlay.new()
	add_child(_skill_overlay)
	_skill_overlay.skill_chosen.connect(_on_skill_card_chosen)
	_skill_overlay.skipped.connect(_on_skill_card_skipped)
	_skill_overlay.show_rewards(skills, GameState.party)

func _on_skill_card_chosen(skill: SkillData, recipient: Character) -> void:
	recipient.add_skill_to_inventory(skill)
	if recipient.skill_slots.size() < 4:
		recipient.skill_slots.append(skill)
	_log("「%s」を %s が習得！" % [skill.skill_name, recipient.char_name])
	await get_tree().create_timer(0.5).timeout
	_after_skill_reward()

func _on_skill_card_skipped() -> void:
	_log("スキルをスキップした。")
	_after_skill_reward()

func _after_skill_reward() -> void:
	if _skill_overlay:
		_skill_overlay.queue_free()
		_skill_overlay = null
	await get_tree().create_timer(0.8).timeout
	if _is_boss_battle:
		var next_chapter := GameState.current_chapter + 1
		if next_chapter > 3:
			GameState.end_run(true)
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			return
		GameState.advance_to_chapter(next_chapter)
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _on_enemy_telegraphed(enemy: EnemyInstance, action: EnemyAction) -> void:
	_log("👁 %s は次のターンに「%s」を使いそうだ。" % [enemy.enemy_data.enemy_name, action.action_name])

# ── Command Handlers ──────────────────────────────────────────

func _on_fight_pressed() -> void:
	if _current_character == null:
		return
	_pending_command = "fight"
	_request_enemy_target()

func _on_skill_pressed() -> void:
	if _current_character == null or _current_character.skill_slots.is_empty():
		return
	_show_skill_list()

func _on_item_pressed() -> void:
	if GameState.items.is_empty():
		_log("アイテムがない！")
		return
	_show_item_list()

func _on_unique_pressed() -> void:
	if _current_character == null:
		return
	var class_type := _current_character.class_data.class_type
	# Determine what targeting we need
	match class_type:
		ClassData.ClassType.WARRIOR, ClassData.ClassType.MAGE, ClassData.ClassType.MONK:
			_battle_manager.submit_player_action("unique")
		ClassData.ClassType.THIEF, ClassData.ClassType.ARCHER:
			_pending_command = "unique"
			_request_enemy_target()
		ClassData.ClassType.CLERIC, ClassData.ClassType.HERO:
			_pending_command = "unique"
			_request_ally_target()
		ClassData.ClassType.SAGE:
			_pending_command = "unique"
			_show_skill_list_for_prophecy()
		_:
			_battle_manager.submit_player_action("unique")

func _show_skill_list() -> void:
	_clear_sub_menu()
	sub_menu.visible = true
	_pending_command = "skill"
	for skill in _current_character.skill_slots:
		if skill == null:
			continue
		var btn := Button.new()
		btn.text = "%s MP:%d — %s" % [skill.skill_name, skill.mp_cost, skill.description]
		btn.disabled = _current_character.current_mp < skill.mp_cost
		btn.pressed.connect(_on_skill_list_item_selected.bind(skill))
		sub_menu.add_child(btn)

func _show_skill_list_for_prophecy() -> void:
	_clear_sub_menu()
	sub_menu.visible = true
	var lbl := Label.new()
	lbl.text = "予言するスキルを選択："
	sub_menu.add_child(lbl)
	for skill in _current_character.skill_slots:
		if skill == null:
			continue
		var btn := Button.new()
		btn.text = "%s MP:%d（次ターン先制）" % [skill.skill_name, skill.mp_cost]
		btn.disabled = _current_character.current_mp < skill.mp_cost
		btn.pressed.connect(_on_prophecy_skill_selected.bind(skill))
		sub_menu.add_child(btn)

func _on_skill_list_item_selected(skill: SkillData) -> void:
	_selected_skill = skill
	_clear_sub_menu()
	# Determine target type from effect
	match skill.effect_type:
		SkillData.EffectType.DAMAGE_SINGLE, SkillData.EffectType.DAMAGE_SINGLE_CONDITIONAL, SkillData.EffectType.DEBUFF_DEF, SkillData.EffectType.STATUS_TAUNT:
			_request_enemy_target()
		SkillData.EffectType.DAMAGE_ALL, SkillData.EffectType.BUFF_ATK:
			_battle_manager.submit_player_action("skill", _selected_skill, -1, -1)
		SkillData.EffectType.HEAL_SINGLE, SkillData.EffectType.BUFF_DEF, SkillData.EffectType.BUFF_SHIELD, SkillData.EffectType.COVER_ALLY, SkillData.EffectType.RESTORE_MP:
			_request_ally_target()
		_:
			_battle_manager.submit_player_action("skill", _selected_skill, -1, -1)

func _on_prophecy_skill_selected(skill: SkillData) -> void:
	_clear_sub_menu()
	_battle_manager.submit_player_action("unique", skill, -1, -1)

func _show_item_list() -> void:
	_clear_sub_menu()
	sub_menu.visible = true
	_pending_command = "item"
	for item in GameState.items:
		var btn := Button.new()
		btn.text = "%s — %s" % [item.item_name, item.description]
		btn.pressed.connect(_on_item_selected.bind(item))
		sub_menu.add_child(btn)

func _on_item_selected(item: ItemData) -> void:
	_clear_sub_menu()
	if item.targets_ally:
		_pending_command = "item_" + str(GameState.items.find(item))
		_request_ally_target()
	else:
		_battle_manager.submit_player_action("item", null, -1, -1, item)

func _request_enemy_target() -> void:
	_select_mode = SelectMode.ENEMY
	_clear_sub_menu()
	sub_menu.visible = true
	var lbl := Label.new()
	lbl.text = "ターゲットを選択："
	sub_menu.add_child(lbl)
	for i in range(_battle_manager.enemies.size()):
		var enemy := _battle_manager.enemies[i]
		if not enemy.is_alive():
			continue
		var btn := Button.new()
		btn.text = "%s HP:%d/%d" % [enemy.enemy_data.enemy_name, enemy.current_hp, enemy.enemy_data.max_hp]
		btn.pressed.connect(_on_enemy_target_selected.bind(i))
		sub_menu.add_child(btn)

func _request_ally_target() -> void:
	_select_mode = SelectMode.ALLY
	_clear_sub_menu()
	sub_menu.visible = true
	var lbl := Label.new()
	lbl.text = "味方を選択："
	sub_menu.add_child(lbl)
	for i in range(_battle_manager.party.size()):
		var member := _battle_manager.party[i]
		if not member.is_alive():
			continue
		var btn := Button.new()
		btn.text = "%s HP:%d/%d" % [member.char_name, member.current_hp, member.max_hp]
		btn.pressed.connect(_on_ally_target_selected.bind(i))
		sub_menu.add_child(btn)

func _on_enemy_target_selected(index: int) -> void:
	_clear_sub_menu()
	_select_mode = SelectMode.NONE
	if _pending_command == "fight":
		_battle_manager.submit_player_action("fight", null, index)
	elif _pending_command == "skill":
		_battle_manager.submit_player_action("skill", _selected_skill, index)
	elif _pending_command == "unique":
		_battle_manager.submit_player_action("unique", null, index, -1)
	_selected_skill = null
	_pending_command = ""

func _on_ally_target_selected(index: int) -> void:
	_clear_sub_menu()
	_select_mode = SelectMode.NONE
	if _pending_command == "skill":
		_battle_manager.submit_player_action("skill", _selected_skill, -1, index)
	elif _pending_command == "unique":
		_battle_manager.submit_player_action("unique", null, -1, index)
	elif _pending_command.begins_with("item_"):
		var item_idx := int(_pending_command.substr(5))
		if item_idx < GameState.items.size():
			_battle_manager.submit_player_action("item", null, -1, index, GameState.items[item_idx])
	_selected_skill = null
	_pending_command = ""

# ── Utilities ─────────────────────────────────────────────────

func _set_commands_enabled(enabled: bool) -> void:
	fight_btn.disabled = not enabled
	skill_btn.disabled = not enabled
	item_btn.disabled = not enabled
	unique_btn.disabled = not enabled

func _clear_sub_menu() -> void:
	for child in sub_menu.get_children():
		child.queue_free()
	sub_menu.visible = false

func _rarity_text(rarity: SkillData.Rarity) -> String:
	match rarity:
		SkillData.Rarity.COMMON: return "コモン"
		SkillData.Rarity.RARE: return "レア"
		SkillData.Rarity.LEGENDARY: return "レジェンド"
	return ""
