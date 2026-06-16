extends Node

const SCENE_MAP := "res://scenes/map/map.tscn"
const SCENE_BATTLE := "res://scenes/battle/battle.tscn"
const SCENE_MAIN_MENU := "res://scenes/main_menu.tscn"

var _current_scene: Node = null

func _ready() -> void:
	GameState.node_entered.connect(_on_node_entered)
	GameState.run_ended.connect(_on_run_ended)
	_go_to(SCENE_MAIN_MENU)

func _go_to(scene_path: String) -> void:
	if _current_scene:
		_current_scene.queue_free()
	var packed: PackedScene = load(scene_path)
	_current_scene = packed.instantiate()
	add_child(_current_scene)

func _on_node_entered(node: MapNodeData) -> void:
	match node.node_type:
		MapNodeData.NodeType.COMBAT, MapNodeData.NodeType.ELITE, MapNodeData.NodeType.BOSS:
			_go_to(SCENE_BATTLE)
		MapNodeData.NodeType.CAMPFIRE, MapNodeData.NodeType.SHOP, MapNodeData.NodeType.EVENT, MapNodeData.NodeType.RECRUIT:
			pass

func _on_run_ended(_victory: bool, _gold: int) -> void:
	await get_tree().create_timer(2.0).timeout
	_go_to(SCENE_MAIN_MENU)
