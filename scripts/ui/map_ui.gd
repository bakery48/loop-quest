extends Control

@onready var chapter_label: Label = $VBox/Header/ChapterLabel
@onready var gold_label: Label = $VBox/Header/GoldLabel
@onready var map_grid: VBoxContainer = $VBox/ScrollContainer/MapGrid
@onready var party_status: Label = $VBox/StatusBar/PartyStatus

## node_id → Button, so we can update button states after navigation.
var _node_buttons: Dictionary = {}

func _ready() -> void:
	GameState.gold_changed.connect(_update_gold)
	GameState.party_changed.connect(_update_party_status)
	_refresh_map()
	_update_party_status()
	_update_gold(GameState.run_gold)
	chapter_label.text = "第%d章" % GameState.current_chapter

func _refresh_map() -> void:
	# Clear existing buttons
	for child in map_grid.get_children():
		child.queue_free()
	_node_buttons.clear()

	# Group nodes by row
	var by_row: Dictionary = {}
	for node in GameState.get_all_map_nodes():
		if not node.row in by_row:
			by_row[node.row] = []
		by_row[node.row].append(node)

	# Render rows from bottom (boss) to top (start) — descending row index
	var sorted_rows := by_row.keys()
	sorted_rows.sort()
	sorted_rows.reverse()

	for row_index in sorted_rows:
		var row_container := HBoxContainer.new()
		row_container.alignment = BoxContainer.ALIGNMENT_CENTER
		map_grid.add_child(row_container)

		for node in by_row[row_index]:
			var btn := Button.new()
			btn.text = node.get_display_name()
			btn.custom_minimum_size = Vector2(100, 40)
			btn.disabled = not node.is_accessible
			if node.is_visited:
				btn.modulate = Color(0.5, 0.5, 0.5)
			if node.is_current:
				btn.modulate = Color(1.0, 1.0, 0.3)
			btn.pressed.connect(_on_node_pressed.bind(node.node_id))
			row_container.add_child(btn)
			_node_buttons[node.node_id] = btn

func _on_node_pressed(node_id: int) -> void:
	GameState.enter_node(node_id)
	var node := GameState.get_current_node()
	if node == null:
		return

	match node.node_type:
		MapNodeData.NodeType.COMBAT, MapNodeData.NodeType.ELITE, MapNodeData.NodeType.BOSS:
			get_tree().change_scene_to_file("res://scenes/battle/battle.tscn")
		MapNodeData.NodeType.CAMPFIRE:
			_show_campfire_options()
		MapNodeData.NodeType.SHOP:
			_show_shop()
		MapNodeData.NodeType.EVENT:
			_show_event()
		MapNodeData.NodeType.RECRUIT:
			_show_recruit()

func _update_gold(amount: int) -> void:
	gold_label.text = "ゴールド: %d" % amount

func _update_party_status() -> void:
	var parts: Array[String] = []
	for member in GameState.party:
		parts.append("%s HP:%d/%d" % [member.char_name, member.current_hp, member.max_hp])
	party_status.text = "  |  ".join(parts)

# ── Placeholder Node Actions ──────────────────────────────────

func _show_campfire_options() -> void:
	# Minimal: just heal party 30% max HP
	for member in GameState.party:
		member.heal(int(member.max_hp * 0.3))
	_update_party_status()
	_refresh_map()

func _show_shop() -> void:
	_refresh_map()  # Shop UI placeholder

func _show_event() -> void:
	_refresh_map()  # Event UI placeholder

func _show_recruit() -> void:
	_refresh_map()  # Recruit UI placeholder
