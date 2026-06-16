class_name MapNodeData
extends RefCounted

enum NodeType {
	COMBAT,
	ELITE,
	EVENT,
	SHOP,
	CAMPFIRE,
	RECRUIT,
	BOSS,
}

var node_id: int
var node_type: NodeType
var row: int
var col: int
## IDs of nodes in the next row that this node connects to.
var next_node_ids: Array[int] = []
var is_visited: bool = false
var is_current: bool = false
var is_accessible: bool = false

func get_display_name() -> String:
	match node_type:
		NodeType.COMBAT: return "⚔ 戦闘"
		NodeType.ELITE: return "💀 精鋭"
		NodeType.EVENT: return "❓ イベント"
		NodeType.SHOP: return "🛒 商店"
		NodeType.CAMPFIRE: return "🔥 焚き火"
		NodeType.RECRUIT: return "👥 仲間加入"
		NodeType.BOSS: return "👑 ボス"
	return "?"

func get_type_color() -> Color:
	match node_type:
		NodeType.COMBAT: return Color.WHITE
		NodeType.ELITE: return Color.ORANGE
		NodeType.EVENT: return Color.CYAN
		NodeType.SHOP: return Color.YELLOW
		NodeType.CAMPFIRE: return Color(1.0, 0.6, 0.2)
		NodeType.RECRUIT: return Color.GREEN
		NodeType.BOSS: return Color.RED
	return Color.GRAY
