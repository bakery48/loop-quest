extends Node

## GameState — singleton managing all run and meta-progression state.

# ── Signals ──────────────────────────────────────────────────
signal run_started()
signal run_ended(victory: bool, gold_earned: int)
signal node_entered(node: MapNodeData)
signal party_changed()
signal gold_changed(new_amount: int)
signal items_changed()

# ── Meta state (persists to disk) ─────────────────────────────
var meta_gold: int = 0
var unlocked_classes: Array[String] = ["HERO", "WARRIOR", "MAGE", "CLERIC"]
var completed_runs: int = 0
var best_chapter_reached: int = 0
var achievements: Array[String] = []

# ── Run state (cleared each run) ─────────────────────────────
var party: Array[Character] = []
var current_chapter: int = 1
var current_map_nodes: Array = []          # Array of MapNodeData
var current_node_id: int = -1
var run_gold: int = 0
var items: Array[ItemData] = []            # party item inventory
var run_rng: RandomNumberGenerator

const SAVE_PATH := "user://meta_save.json"

func _ready() -> void:
	run_rng = RandomNumberGenerator.new()
	load_meta()

# ── Run Lifecycle ─────────────────────────────────────────────

func start_new_run(selected_class_ids: Array[String]) -> void:
	run_rng.randomize()
	party.clear()
	items.clear()
	run_gold = 0
	current_chapter = 1
	current_node_id = -1

	for class_id in selected_class_ids:
		var class_data := ClassDatabase.get_class(class_id)
		if class_data:
			var character := Character.create(class_data)
			party.append(character)

	_generate_chapter_map(1)
	run_started.emit()

func end_run(victory: bool) -> void:
	meta_gold += run_gold
	completed_runs += 1
	if current_chapter > best_chapter_reached:
		best_chapter_reached = current_chapter
	if victory:
		achievements.append("FIRST_CLEAR") if not "FIRST_CLEAR" in achievements else null
	save_meta()
	run_ended.emit(victory, run_gold)

func advance_to_chapter(chapter: int) -> void:
	current_chapter = chapter
	_generate_chapter_map(chapter)

# ── Map Navigation ────────────────────────────────────────────

func enter_node(node_id: int) -> void:
	var node := _get_node(node_id)
	if node == null or not node.is_accessible:
		return
	# Mark previous current as visited
	if current_node_id >= 0:
		var prev := _get_node(current_node_id)
		if prev:
			prev.is_visited = true
			prev.is_current = false

	current_node_id = node_id
	node.is_current = true
	MapGenerator.mark_accessible(current_map_nodes, node_id)
	node_entered.emit(node)

func get_current_node() -> MapNodeData:
	return _get_node(current_node_id)

func get_all_map_nodes() -> Array:
	return current_map_nodes

# ── Party Management ──────────────────────────────────────────

func add_skill_to_party_member(skill: SkillData, char_index: int) -> void:
	if char_index < 0 or char_index >= party.size():
		return
	party[char_index].add_skill_to_inventory(skill)
	party_changed.emit()

func replace_party_member(old_index: int, new_class_id: String) -> void:
	if old_index < 0 or old_index >= party.size():
		return
	var class_data := ClassDatabase.get_class(new_class_id)
	if class_data == null:
		return
	party[old_index] = Character.create(class_data)
	party_changed.emit()

func get_party_class_ids() -> Array[String]:
	var ids: Array[String] = []
	for member in party:
		ids.append(member.class_data.class_id)
	return ids

# ── Economy ───────────────────────────────────────────────────

func collect_gold(amount: int) -> void:
	run_gold += amount
	gold_changed.emit(run_gold)

func spend_run_gold(amount: int) -> bool:
	if run_gold < amount:
		return false
	run_gold -= amount
	gold_changed.emit(run_gold)
	return true

# ── Items ─────────────────────────────────────────────────────

func add_item(item: ItemData) -> void:
	items.append(item)
	items_changed.emit()

func use_item(item: ItemData, target: Character) -> bool:
	if not item in items:
		return false
	items.erase(item)
	match item.item_type:
		ItemData.ItemType.HEAL_HP:
			target.heal(int(item.power))
		ItemData.ItemType.HEAL_MP:
			target.restore_mp(int(item.power))
		ItemData.ItemType.BUFF_ATK_TEMP:
			var buff := StatusEffect.new(StatusEffect.EffectType.ATK_BUFF, item.duration, 1, "ITEM")
			target.add_status(buff)
		ItemData.ItemType.BUFF_DEF_TEMP:
			var buff := StatusEffect.new(StatusEffect.EffectType.DEF_BUFF, item.duration, 1, "ITEM")
			target.add_status(buff)
	items_changed.emit()
	return true

# ── Meta Persistence ──────────────────────────────────────────

func save_meta() -> void:
	var data := {
		"meta_gold": meta_gold,
		"unlocked_classes": unlocked_classes,
		"completed_runs": completed_runs,
		"best_chapter_reached": best_chapter_reached,
		"achievements": achievements,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_meta() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var result := JSON.parse_string(file.get_as_text())
	if result == null or not result is Dictionary:
		return
	var data: Dictionary = result
	meta_gold = data.get("meta_gold", 0)
	unlocked_classes = data.get("unlocked_classes", ["HERO", "WARRIOR", "MAGE", "CLERIC"])
	completed_runs = data.get("completed_runs", 0)
	best_chapter_reached = data.get("best_chapter_reached", 0)
	achievements = data.get("achievements", [])

# ── Helpers ───────────────────────────────────────────────────

func _generate_chapter_map(chapter: int) -> void:
	current_map_nodes = MapGenerator.generate_chapter(chapter, run_rng)
	MapGenerator.mark_start_accessible(current_map_nodes)

func _get_node(node_id: int) -> MapNodeData:
	for node in current_map_nodes:
		if node.node_id == node_id:
			return node
	return null
