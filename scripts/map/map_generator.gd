class_name MapGenerator
extends RefCounted

const ROWS_PER_CHAPTER: int = 12

## Weight table for non-special rows (row 0 = always COMBAT, last row = always BOSS).
const NODE_TYPE_WEIGHTS: Dictionary = {
	MapNodeData.NodeType.COMBAT:   45,
	MapNodeData.NodeType.ELITE:    10,
	MapNodeData.NodeType.EVENT:    20,
	MapNodeData.NodeType.SHOP:      8,
	MapNodeData.NodeType.CAMPFIRE: 12,
	MapNodeData.NodeType.RECRUIT:   5,
}

## Generates all nodes for one chapter. Returns a flat Array[MapNodeData].
## The caller stores this in GameState.current_map_nodes.
static func generate_chapter(chapter: int, rng: RandomNumberGenerator) -> Array:
	var all_nodes: Array = []
	var node_id_counter := chapter * 1000  # unique IDs per chapter

	# Row layout: array of arrays of MapNodeData
	var rows: Array = []

	for row_index in range(ROWS_PER_CHAPTER + 1):  # +1 for boss row
		var is_boss_row := row_index == ROWS_PER_CHAPTER
		var is_first_row := row_index == 0

		var num_cols: int
		if is_boss_row:
			num_cols = 1
		elif is_first_row:
			num_cols = 3
		else:
			num_cols = rng.randi_range(2, 4)

		var row_nodes: Array = []
		for col in range(num_cols):
			var node := MapNodeData.new()
			node.node_id = node_id_counter
			node_id_counter += 1
			node.row = row_index
			node.col = col

			if is_boss_row:
				node.node_type = MapNodeData.NodeType.BOSS
			elif is_first_row:
				node.node_type = MapNodeData.NodeType.COMBAT
			else:
				node.node_type = _weighted_random_type(rng)

			row_nodes.append(node)
			all_nodes.append(node)

		rows.append(row_nodes)

	_assign_connections(rows, rng)
	return all_nodes

## Connect each node to 1-2 nodes in the next row.
## Guarantees no node in row N is unreachable from row 0.
static func _assign_connections(rows: Array, rng: RandomNumberGenerator) -> void:
	for r in range(rows.size() - 1):
		var current_row: Array = rows[r]
		var next_row: Array = rows[r + 1]

		# First pass: ensure every next-row node has at least one predecessor
		var next_has_connection := {}
		for n in next_row:
			next_has_connection[n.node_id] = false

		for node in current_row:
			# Each current node connects to 1 or 2 next nodes
			var max_connections := mini(2, next_row.size())
			var num_connections := rng.randi_range(1, max_connections)

			# Pick random targets (no duplicates)
			var targets: Array = next_row.duplicate()
			targets.shuffle()
			for i in range(num_connections):
				var target: MapNodeData = targets[i]
				if not target.node_id in node.next_node_ids:
					node.next_node_ids.append(target.node_id)
					next_has_connection[target.node_id] = true

		# Second pass: ensure every next-row node has at least one connection
		for next_node in next_row:
			if not next_has_connection[next_node.node_id]:
				# Connect a random current-row node to it
				var src: MapNodeData = current_row[rng.randi() % current_row.size()]
				if not next_node.node_id in src.next_node_ids:
					src.next_node_ids.append(next_node.node_id)

## Mark which nodes are accessible from a given node ID.
## Call after the player moves to a new node.
static func mark_accessible(all_nodes: Array, from_node_id: int) -> void:
	# Build id → node map
	var node_map: Dictionary = {}
	for node in all_nodes:
		node_map[node.node_id] = node

	# Reset all accessibility
	for node in all_nodes:
		node.is_accessible = false

	if not from_node_id in node_map:
		return

	var source: MapNodeData = node_map[from_node_id]
	for next_id in source.next_node_ids:
		if next_id in node_map:
			node_map[next_id].is_accessible = true

## Mark the starting nodes (row 0) as accessible at run start.
static func mark_start_accessible(all_nodes: Array) -> void:
	for node in all_nodes:
		if node.row == 0:
			node.is_accessible = true

static func _weighted_random_type(rng: RandomNumberGenerator) -> MapNodeData.NodeType:
	var total := 0
	for w in NODE_TYPE_WEIGHTS.values():
		total += w
	var roll := rng.randi() % total
	var cumulative := 0
	for type in NODE_TYPE_WEIGHTS:
		cumulative += NODE_TYPE_WEIGHTS[type]
		if roll < cumulative:
			return type
	return MapNodeData.NodeType.COMBAT
