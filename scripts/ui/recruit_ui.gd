extends Control

## Multi-step wizard for party member recruitment.
##
## Step 1: Choose which candidate joins (3 options)
## Step 2: Choose which current member leaves
## Step 3: Assign each departing member's skill to a recipient (or LOST)
## Step 4: Confirm summary → execute swap

@onready var step_label: Label = $VBox/StepLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var content_area: VBoxContainer = $VBox/ContentArea
@onready var button_row: HBoxContainer = $VBox/ButtonRow

var _candidates: Array[ClassData] = []
var _chosen_candidate: ClassData = null
var _leaving_index: int = -1
## Dictionary: SkillData → party_index (int) receiving the skill, or -1 for LOST.
var _inheritance_map: Dictionary = {}
## Skills to assign, processed one at a time in step 3.
var _skills_to_assign: Array[SkillData] = []
var _current_skill_index: int = 0

func _ready() -> void:
	_candidates = GameState.get_recruit_candidates()
	_show_step1()

# ── Step 1: Choose candidate ──────────────────────────────────

func _show_step1() -> void:
	step_label.text = "STEP 1 / 3 — 仲間を選ぶ"
	desc_label.text = "パーティに加わる仲間を1人選んでください。"
	_clear_content()

	if _candidates.is_empty():
		desc_label.text = "加入できる候補がいません。"
		var btn := Button.new()
		btn.text = "マップに戻る"
		btn.pressed.connect(_on_cancel)
		button_row.add_child(btn)
		return

	for candidate in _candidates:
		var card := _make_candidate_card(candidate)
		content_area.add_child(card)

	_add_cancel_button()

func _make_candidate_card(cd: ClassData) -> PanelContainer:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = cd.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "HP:%d  MP:%d  ATK:%d  DEF:%d  SPD:%d" % [
		cd.base_hp, cd.base_mp, cd.base_atk, cd.base_def, cd.base_spd]
	vbox.add_child(stats_lbl)

	var passive_lbl := Label.new()
	passive_lbl.text = "【%s】%s" % [cd.passive_name, cd.passive_description]
	passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(passive_lbl)

	var cmd_lbl := Label.new()
	cmd_lbl.text = "固有: %s — %s" % [cd.unique_command_name, cd.unique_command_description]
	cmd_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(cmd_lbl)

	var starting_lbl := Label.new()
	var skill_names: Array[String] = []
	for s in cd.starting_skills:
		skill_names.append(s.skill_name)
	starting_lbl.text = "初期スキル: %s" % (", ".join(skill_names) if not skill_names.is_empty() else "なし")
	vbox.add_child(starting_lbl)

	var select_btn := Button.new()
	select_btn.text = "この仲間を選ぶ"
	select_btn.pressed.connect(_on_candidate_chosen.bind(cd))
	vbox.add_child(select_btn)

	return panel

func _on_candidate_chosen(cd: ClassData) -> void:
	_chosen_candidate = cd
	_show_step2()

# ── Step 2: Choose who leaves ─────────────────────────────────

func _show_step2() -> void:
	step_label.text = "STEP 2 / 3 — 離脱メンバーを選ぶ"
	desc_label.text = "「%s」が加わります。誰をパーティから外しますか？\n※ 離脱メンバーのスキルは次のステップで引き継ぎ先を選べます。" % _chosen_candidate.display_name
	_clear_content()

	for i in range(GameState.party.size()):
		var member := GameState.party[i]
		var card := _make_leaving_card(member, i)
		content_area.add_child(card)

	_add_back_button(_show_step1)

func _make_leaving_card(member: Character, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s（%s）" % [member.char_name, member.class_data.display_name]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP:%d/%d  MP:%d/%d" % [member.current_hp, member.max_hp, member.current_mp, member.max_mp]
	vbox.add_child(hp_lbl)

	var skill_names: Array[String] = []
	for s in member.skill_inventory:
		skill_names.append(s.skill_name)
	var skills_lbl := Label.new()
	skills_lbl.text = "スキル: %s" % (", ".join(skill_names) if not skill_names.is_empty() else "なし")
	skills_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(skills_lbl)

	var select_btn := Button.new()
	select_btn.text = "このメンバーを外す"
	select_btn.pressed.connect(_on_leaving_chosen.bind(index))
	vbox.add_child(select_btn)

	return panel

func _on_leaving_chosen(index: int) -> void:
	_leaving_index = index
	_inheritance_map.clear()
	_skills_to_assign = GameState.party[index].skill_inventory.duplicate()
	_current_skill_index = 0
	_show_step3_next_skill()

# ── Step 3: Skill inheritance (one skill at a time) ───────────

func _show_step3_next_skill() -> void:
	# Skip skills with no eligible recipients immediately (mark as LOST)
	while _current_skill_index < _skills_to_assign.size():
		var skill := _skills_to_assign[_current_skill_index]
		var eligible := _get_eligible_recipients(skill)
		if eligible.is_empty():
			_inheritance_map[skill] = -1  # LOST
			_current_skill_index += 1
		else:
			break

	if _current_skill_index >= _skills_to_assign.size():
		_show_step4_confirm()
		return

	var skill := _skills_to_assign[_current_skill_index]
	var eligible := _get_eligible_recipients(skill)

	step_label.text = "STEP 3 / 3 — スキル引き継ぎ (%d/%d)" % [
		_current_skill_index + 1, _skills_to_assign.size()]
	desc_label.text = "「%s」を誰が引き継ぎますか？（%s）" % [skill.skill_name, skill.description]
	_clear_content()

	# Skill detail card
	var detail := _make_skill_detail_card(skill)
	content_area.add_child(detail)

	var choices_label := Label.new()
	choices_label.text = "── 引き継ぎ先 ──"
	content_area.add_child(choices_label)

	# Eligible party members (excluding leaving member)
	for i in eligible:
		var member := GameState.party[i]
		var btn := Button.new()
		btn.text = "%s（%s）  スロット: %d/4" % [
			member.char_name, member.class_data.display_name, member.skill_slots.size()]
		btn.pressed.connect(_on_skill_recipient_chosen.bind(skill, i))
		content_area.add_child(btn)

	var lose_btn := Button.new()
	lose_btn.text = "ロスト（消滅）"
	lose_btn.modulate = Color.RED
	lose_btn.pressed.connect(_on_skill_lost.bind(skill))
	content_area.add_child(lose_btn)

	_add_back_button(_go_back_in_step3)

func _make_skill_detail_card(skill: SkillData) -> PanelContainer:
	var panel := PanelContainer.new()
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = "%s  【%s】  MP:%d" % [skill.skill_name, _rarity_text(skill.rarity), skill.mp_cost]
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = skill.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	var cls_lbl := Label.new()
	cls_lbl.text = "装備可能: %s" % ("全員" if skill.allowed_classes.is_empty() else ", ".join(skill.allowed_classes))
	vbox.add_child(cls_lbl)

	return panel

func _get_eligible_recipients(skill: SkillData) -> Array[int]:
	var out: Array[int] = []
	for i in range(GameState.party.size()):
		if i == _leaving_index:
			continue
		if GameState.party[i].can_equip_skill(skill):
			out.append(i)
	return out

func _on_skill_recipient_chosen(skill: SkillData, party_index: int) -> void:
	_inheritance_map[skill] = party_index
	_current_skill_index += 1
	_show_step3_next_skill()

func _on_skill_lost(skill: SkillData) -> void:
	_inheritance_map[skill] = -1
	_current_skill_index += 1
	_show_step3_next_skill()

func _go_back_in_step3() -> void:
	if _current_skill_index > 0:
		_current_skill_index -= 1
		# Remove the assignment we're going back to
		if _current_skill_index < _skills_to_assign.size():
			_inheritance_map.erase(_skills_to_assign[_current_skill_index])
		_show_step3_next_skill()
	else:
		_show_step2()

# ── Step 4: Confirm ───────────────────────────────────────────

func _show_step4_confirm() -> void:
	step_label.text = "確認"
	_clear_content()

	var leaving_name := GameState.party[_leaving_index].char_name
	desc_label.text = "「%s」が離脱し、「%s」が加わります。" % [leaving_name, _chosen_candidate.display_name]

	# Show inheritance summary
	var summary_lbl := Label.new()
	var lines: Array[String] = ["── スキル引き継ぎ ──"]
	for skill in _inheritance_map:
		var idx: int = _inheritance_map[skill]
		if idx < 0:
			lines.append("  %s → ロスト（消滅）" % skill.skill_name)
		else:
			lines.append("  %s → %s" % [skill.skill_name, GameState.party[idx].char_name])
	summary_lbl.text = "\n".join(lines)
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_area.add_child(summary_lbl)

	var confirm_btn := Button.new()
	confirm_btn.text = "確定して交代する"
	confirm_btn.pressed.connect(_on_confirm)
	button_row.add_child(confirm_btn)

	_add_back_button(func():
		button_row.get_children().back().queue_free()
		_go_back_in_step3()
	)

func _on_confirm() -> void:
	GameState.execute_party_swap(_leaving_index, _chosen_candidate.class_id, _inheritance_map)
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

# ── Helpers ───────────────────────────────────────────────────

func _clear_content() -> void:
	for child in content_area.get_children():
		child.queue_free()
	for child in button_row.get_children():
		child.queue_free()

func _add_cancel_button() -> void:
	var btn := Button.new()
	btn.text = "キャンセル（マップに戻る）"
	btn.pressed.connect(_on_cancel)
	button_row.add_child(btn)

func _add_back_button(callback: Callable) -> void:
	var btn := Button.new()
	btn.text = "← 戻る"
	btn.pressed.connect(callback)
	button_row.add_child(btn)

func _on_cancel() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _rarity_text(rarity: SkillData.Rarity) -> String:
	match rarity:
		SkillData.Rarity.COMMON: return "コモン"
		SkillData.Rarity.RARE: return "レア"
		SkillData.Rarity.LEGENDARY: return "レジェンド"
	return ""
