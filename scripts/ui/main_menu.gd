extends Control

func _ready() -> void:
	$VBox/NewRunBtn.pressed.connect(_on_new_run)
	$VBox/ContinueBtn.pressed.connect(_on_continue)

func _on_new_run() -> void:
	# Default starter party: Hero, Warrior, Mage, Cleric
	GameState.start_new_run(["HERO", "WARRIOR", "MAGE", "CLERIC"])
	# Navigate to map
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _on_continue() -> void:
	# No save/load for runs yet — just start fresh
	_on_new_run()
