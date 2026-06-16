extends Control

@onready var party_status: Label = $VBox/PartyStatus
@onready var heal_btn: Button = $VBox/OptionButtons/HealBtn
@onready var slot_btn: Button = $VBox/OptionButtons/SlotBtn
@onready var leave_btn: Button = $VBox/OptionButtons/LeaveBtn
@onready var slot_panel: ScrollContainer = $VBox/SlotPanel
@onready var slot_content: VBoxContainer = $VBox/SlotPanel/SlotContent

var _heal_used := false
## When non-null, the player clicked a skill and is choosing which slot to place it in.
var _pending_skill: SkillData = null
var _pending_skill_owner: Character = null

func _ready() -> void:
	heal_btn.pressed.connect(_on_heal)
	slot_btn.pressed.connect(_on_toggle_slots)
	leave_btn.pressed.connect(_on_leave)
	_refresh_party_status()

func _refresh_party_status() -> void:
	var parts: Array[String] = []
	for member in GameState.party:
		parts.append("%s  HP:%d/%d  MP:%d/%d" % [
			member.char_name, member.current_hp, member.max_hp,
			member.current_mp, member.max_mp])
	party_status.text = "\n".join(parts)

# ── HP回復 ────────────────────────────────────────────────────

func _on_heal() -> void:
	if _heal_used:
		heal_btn.text = "HP回復\n（使用済み）"
		return
	_heal_used = true
	for member in GameState.party:
		member.heal(int(member.max_hp * 0.3))
	_refresh_party_status()
	heal_btn.text = "HP回復\n（使用済み）"
	heal_btn.disabled = true

# ── スロット変更 ──────────────────────────────────────────────

func _on_toggle_slots() -> void:
	if slot_panel.visible:
		slot_panel.visible = false
		slot_btn.text = "スロット変更\n（スキル装備整理）"
	else:
		slot_panel.visible = true
		slot_btn.text = "スロット変更\n（閉じる）"
		_build_slot_ui()

func _build_slot_ui() -> void:
	for child in slot_content.get_children():
		child.queue_free()
	_pending_skill = null
	_pending_skill_owner = null

	for member in GameState.party:
		var member_section := _make_member_section(member)
		slot_content.add_child(member_section)
		slot_content.add_child(HSeparator.new())

func _make_member_section(member: Character) -> VBoxContainer:
	var vbox := VBoxContainer.new()

	var header := Label.new()
	header.text = "▶ %s（%s）" % [member.char_name, member.class_data.display_name]
	vbox.add_child(header)

	# ── 装備スロット ──
	var slot_label := Label.new()
	slot_label.text = "装備スロット（最大4）:"
	vbox.add_child(slot_label)

	var slots_hbox := HBoxContainer.new()
	for i in range(4):
		var skill: SkillData = member.skill_slots[i] if i < member.skill_slots.size() else null
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 50)
		btn.text = "[スロット%d]\n%s" % [i + 1, skill.skill_name if skill else "（空）"]
		if skill:
			btn.tooltip_text = skill.description
			btn.pressed.connect(_on_slot_clicked.bind(member, i))
		slots_hbox.add_child(btn)
	vbox.add_child(slots_hbox)

	# ── インベントリ（未装備スキル） ──
	var unequipped := _get_unequipped_skills(member)
	if not unequipped.is_empty():
		var inv_label := Label.new()
		inv_label.text = "未装備スキル（クリックで装備）:"
		vbox.add_child(inv_label)

		var inv_hbox := HBoxContainer.new()
		for skill in unequipped:
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(160, 50)
			btn.text = skill.skill_name + "\nMP:%d" % skill.mp_cost
			btn.tooltip_text = skill.description
			btn.pressed.connect(_on_inventory_skill_clicked.bind(member, skill))
			inv_hbox.add_child(btn)
		vbox.add_child(inv_hbox)
	else:
		var no_inv := Label.new()
		no_inv.text = "（未装備スキルなし）"
		vbox.add_child(no_inv)

	return vbox

func _get_unequipped_skills(member: Character) -> Array[SkillData]:
	var out: Array[SkillData] = []
	for skill in member.skill_inventory:
		if not skill in member.skill_slots:
			out.append(skill)
	return out

## Clicking an equipped slot: unequip it (remove from slots, keep in inventory).
func _on_slot_clicked(member: Character, slot_index: int) -> void:
	if slot_index >= member.skill_slots.size():
		return
	member.skill_slots.remove_at(slot_index)
	_build_slot_ui()

## Clicking an unequipped skill: equip it to the first empty slot,
## or if all slots full, replace the oldest (slot 0) and push the rest forward.
func _on_inventory_skill_clicked(member: Character, skill: SkillData) -> void:
	if member.skill_slots.size() < 4:
		member.skill_slots.append(skill)
	else:
		# Ask user which slot to replace — show a slot-pick prompt
		_pending_skill = skill
		_pending_skill_owner = member
		_show_slot_replace_prompt(member, skill)
		return
	_build_slot_ui()

func _show_slot_replace_prompt(member: Character, skill: SkillData) -> void:
	# Rebuild, but for this member add "どのスロットと交換？" buttons
	for child in slot_content.get_children():
		child.queue_free()

	var prompt := Label.new()
	prompt.text = "「%s」をどのスロットと交換しますか？" % skill.skill_name
	slot_content.add_child(prompt)

	var hbox := HBoxContainer.new()
	for i in range(member.skill_slots.size()):
		var existing: SkillData = member.skill_slots[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 50)
		btn.text = "[スロット%d]\n%s" % [i + 1, existing.skill_name if existing else "（空）"]
		btn.pressed.connect(_on_replace_slot_chosen.bind(member, i, skill))
		hbox.add_child(btn)
	slot_content.add_child(hbox)

	var cancel := Button.new()
	cancel.text = "キャンセル"
	cancel.pressed.connect(_build_slot_ui)
	slot_content.add_child(cancel)

func _on_replace_slot_chosen(member: Character, slot_index: int, new_skill: SkillData) -> void:
	member.skill_slots[slot_index] = new_skill
	_pending_skill = null
	_pending_skill_owner = null
	_build_slot_ui()

# ── 出発 ─────────────────────────────────────────────────────

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")
