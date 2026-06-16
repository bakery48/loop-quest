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

func _start_battle() -> void:
	var node := GameState.get_current_node()
	var is_elite := node != null and node.node_type == MapNodeData.NodeType.ELITE
	var is_boss := node != null and node.node_type == MapNodeData.NodeType.BOSS

	var enemies := _generate_enemies(GameState.current_chapter, is_elite, is_boss)
	_battle_manager.setup_battle(GameState.party, enemies, is_elite)
	_build_enemy_area()
	_build_party_area()
	_battle_manager.start_battle()

func _generate_enemies(chapter: int, elite: bool, boss: bool) -> Array[EnemyData]:
	# Placeholder: generate simple enemies based on chapter
	var out: Array[EnemyData] = []
	if boss:
		out.append(_make_enemy("ボス", chapter * 200, chapter * 25, chapter * 8, chapter * 7, true, true))
	elif elite:
		out.append(_make_enemy("精鋭モンスター", chapter * 80, chapter * 14, chapter * 5, chapter * 5, true, false))
		out.append(_make_enemy("精鋭モンスターB", chapter * 60, chapter * 12, chapter * 4, chapter * 6, true, false))
	else:
		out.append(_make_enemy("スライム", chapter * 40, chapter * 8, chapter * 3, chapter * 4, true, false))
		out.append(_make_enemy("ゴブリン", chapter * 35, chapter * 9, chapter * 2, chapter * 5, true, false))
	return out

func _make_enemy(name: String, hp: int, atk: int, def_v: int, spd: int, steal: bool, _is_boss: bool) -> EnemyData:
	var d := EnemyData.new()
	d.enemy_name = name
	d.max_hp = hp; d.atk = atk; d.def_stat = def_v; d.spd = spd
	d.gold_min = atk; d.gold_max = atk * 3
	d.can_be_stolen_from = steal
	# Add a basic attack action
	var attack := EnemyAction.new()
	attack.action_name = "通常攻撃"; attack.action_type = EnemyAction.ActionType.ATTACK_SINGLE
	attack.power = 1.0; attack.weight = 1.0
	d.actions.append(attack)
	return d

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
		var name_lbl := Label.new()
		name_lbl.text = enemy.enemy_data.enemy_name
		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d/%d" % [enemy.current_hp, enemy.enemy_data.max_hp]
		_enemy_hp_labels.append(hp_lbl)
		enemy.hp_changed.connect(func(hp, max_hp): hp_lbl.text = "HP: %d/%d" % [hp, max_hp])
		vbox.add_child(name_lbl)
		vbox.add_child(hp_lbl)
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
	if victory:
		_log("\n✨ 勝利！")
	else:
		_log("\n💀 全滅…")
	await get_tree().create_timer(3.0).timeout
	if victory:
		get_tree().change_scene_to_file("res://scenes/map/map.tscn")
	else:
		GameState.end_run(false)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_skill_reward(skills: Array) -> void:
	_clear_sub_menu()
	sub_menu.visible = true
	var lbl := Label.new()
	lbl.text = "スキルを1つ選んでください："
	sub_menu.add_child(lbl)
	for skill in skills:
		var btn := Button.new()
		btn.text = "%s（%s）MP:%d — %s" % [skill.skill_name, _rarity_text(skill.rarity), skill.mp_cost, skill.description]
		btn.pressed.connect(_on_skill_reward_selected.bind(skill))
		sub_menu.add_child(btn)

func _on_skill_reward_selected(skill: SkillData) -> void:
	# Give to the first party member who can equip it, or first member
	var recipient: Character = null
	for member in GameState.party:
		if member.can_equip_skill(skill):
			recipient = member
			break
	if recipient == null and not GameState.party.is_empty():
		recipient = GameState.party[0]
	if recipient:
		recipient.add_skill_to_inventory(skill)
		if recipient.skill_slots.size() < 4:
			recipient.skill_slots.append(skill)
		_log("「%s」を %s が習得！" % [skill.skill_name, recipient.char_name])
	_clear_sub_menu()
	# Return to map
	await get_tree().create_timer(1.0).timeout
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
		SkillData.EffectType.DAMAGE_SINGLE, SkillData.EffectType.DAMAGE_SINGLE_CONDITIONAL,
		SkillData.EffectType.DEBUFF_DEF, SkillData.EffectType.STATUS_TAUNT:
			_request_enemy_target()
		SkillData.EffectType.DAMAGE_ALL, SkillData.EffectType.BUFF_ATK:
			_battle_manager.submit_player_action("skill", _selected_skill, -1, -1)
		SkillData.EffectType.HEAL_SINGLE, SkillData.EffectType.BUFF_DEF,
		SkillData.EffectType.BUFF_SHIELD, SkillData.EffectType.COVER_ALLY,
		SkillData.EffectType.RESTORE_MP:
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
