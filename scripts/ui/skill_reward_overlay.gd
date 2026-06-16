class_name SkillRewardOverlay
extends CanvasLayer

## Skill card selection overlay shown after battle victory.
## Usage: instantiate, add_child to scene tree, call show_rewards(skills, party).

signal skill_chosen(skill: SkillData, recipient: Character)
signal skipped()

const RARITY_COLORS := {
	SkillData.Rarity.COMMON:    Color(0.55, 0.55, 0.60),
	SkillData.Rarity.RARE:      Color(0.20, 0.50, 0.90),
	SkillData.Rarity.LEGENDARY: Color(0.85, 0.65, 0.10),
}
const RARITY_LABELS := {
	SkillData.Rarity.COMMON:    "コモン",
	SkillData.Rarity.RARE:      "レア",
	SkillData.Rarity.LEGENDARY: "レジェンダリー",
}

var _party: Array[Character] = []
var _selected_skill: SkillData = null

var _bg: ColorRect
var _container: VBoxContainer

func _ready() -> void:
	layer = 10
	_build_bg()

func show_rewards(skills: Array, party: Array[Character]) -> void:
	_party = party
	_clear()
	_bg.visible = true
	_show_card_step(skills)

# ── Step 1: pick a skill ─────────────────────────────────────────

func _show_card_step(skills: Array) -> void:
	_clear_container()

	var title := Label.new()
	title.text = "✨ スキルを1つ選んでください"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	_container.add_child(title)

	var card_row := HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 16)
	_container.add_child(card_row)

	for skill: SkillData in skills:
		card_row.add_child(_make_card(skill))

	var skip_btn := Button.new()
	skip_btn.text = "スキップ"
	skip_btn.custom_minimum_size = Vector2(120, 36)
	skip_btn.pressed.connect(_on_skip)
	var skip_row := HBoxContainer.new()
	skip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_row.add_child(skip_btn)
	_container.add_child(skip_row)

func _make_card(skill: SkillData) -> PanelContainer:
	var rarity_color: Color = RARITY_COLORS.get(skill.rarity, Color.GRAY)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 280)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16)
	style.border_width_left   = 3
	style.border_width_right  = 3
	style.border_width_top    = 3
	style.border_width_bottom = 3
	style.border_color = rarity_color
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Rarity badge
	var rarity_lbl := Label.new()
	rarity_lbl.text = "【%s】" % RARITY_LABELS.get(skill.rarity, "?")
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_color_override("font_color", rarity_color)
	rarity_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(rarity_lbl)

	# Skill name
	var name_lbl := Label.new()
	name_lbl.text = skill.skill_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", rarity_color)
	vbox.add_child(sep)

	# MP cost
	var mp_lbl := Label.new()
	mp_lbl.text = "MP消費: %d" % skill.mp_cost
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	mp_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(mp_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = skill.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(180, 0)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc_lbl)

	# Allowed classes
	var classes_lbl := Label.new()
	if skill.allowed_classes.is_empty():
		classes_lbl.text = "全職業"
	else:
		classes_lbl.text = _class_display(skill.allowed_classes)
	classes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	classes_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	classes_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(classes_lbl)

	# Equippable by current party indicator
	var can_equip := _who_can_equip(skill)
	var equip_lbl := Label.new()
	if can_equip.is_empty():
		equip_lbl.text = "※習得不可（パーティ）"
		equip_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	else:
		var names := ", ".join(can_equip.map(func(c: Character) -> String: return c.char_name))
		equip_lbl.text = "習得可: " + names
		equip_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	equip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equip_lbl.custom_minimum_size = Vector2(180, 0)
	equip_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(equip_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Select button
	var btn := Button.new()
	btn.text = "選択"
	btn.custom_minimum_size = Vector2(0, 36)
	if can_equip.is_empty():
		btn.disabled = true
	btn.pressed.connect(_on_card_selected.bind(skill))
	vbox.add_child(btn)

	return panel

# ── Step 2: pick a recipient ──────────────────────────────────────

func _on_card_selected(skill: SkillData) -> void:
	_selected_skill = skill
	var eligible := _who_can_equip(skill)
	if eligible.size() == 1:
		_finish(skill, eligible[0])
		return
	_show_recipient_step(skill, eligible)

func _show_recipient_step(skill: SkillData, eligible: Array[Character]) -> void:
	_clear_container()

	var title := Label.new()
	title.text = "「%s」を誰に習得させますか？" % skill.skill_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	_container.add_child(title)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	_container.add_child(btn_row)

	for member: Character in eligible:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(140, 100)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.16)
		style.border_width_left = style.border_width_right = style.border_width_top = style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.7, 1.0)
		style.corner_radius_top_left = style.corner_radius_top_right = style.corner_radius_bottom_left = style.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		panel.add_child(vbox)

		var name_lbl := Label.new()
		name_lbl.text = member.char_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 15)
		vbox.add_child(name_lbl)

		var class_lbl := Label.new()
		class_lbl.text = member.class_data.display_name
		class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		class_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		class_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(class_lbl)

		var slots_lbl := Label.new()
		slots_lbl.text = "スロット: %d/4" % member.skill_slots.size()
		slots_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slots_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if member.skill_slots.size() < 4 else Color(1.0, 0.6, 0.3))
		slots_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(slots_lbl)

		var btn := Button.new()
		btn.text = "渡す"
		btn.pressed.connect(_finish.bind(skill, member))
		vbox.add_child(btn)

		btn_row.add_child(panel)

# ── Finish ────────────────────────────────────────────────────────

func _finish(skill: SkillData, recipient: Character) -> void:
	_bg.visible = false
	skill_chosen.emit(skill, recipient)

func _on_skip() -> void:
	_bg.visible = false
	skipped.emit()

# ── Layout Helpers ────────────────────────────────────────────────

func _build_bg() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.75)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.visible = false
	add_child(_bg)

	_container = VBoxContainer.new()
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", 20)
	_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bg.add_child(_container)

func _clear_container() -> void:
	for child in _container.get_children():
		child.queue_free()

func _clear() -> void:
	_clear_container()

func _who_can_equip(skill: SkillData) -> Array[Character]:
	var out: Array[Character] = []
	for member: Character in _party:
		if member.can_equip_skill(skill):
			out.append(member)
	return out

func _class_display(class_ids: Array[String]) -> String:
	var names: Array[String] = []
	for cid in class_ids:
		var cd := ClassDatabase.find_class(cid)
		names.append(cd.display_name if cd else cid)
	return ", ".join(names)
