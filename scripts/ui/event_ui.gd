extends Control

## Random event node screen. Picks one event at random on entry, presents
## the player with a flavor description and 2-3 choices, applies the chosen
## effect, then lets the player leave back to the map.

var _vbox: VBoxContainer
var _choices_box: VBoxContainer
var _result_label: RichTextLabel
var _leave_btn: Button
var _resolved: bool = false

func _ready() -> void:
	_build_layout()
	_show_random_event()

# ── Layout ────────────────────────────────────────────────────────

func _build_layout() -> void:
	_vbox = VBoxContainer.new()
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vbox.offset_left = 48
	_vbox.offset_top = 48
	_vbox.offset_right = -48
	_vbox.offset_bottom = -48
	_vbox.add_theme_constant_override("separation", 18)
	add_child(_vbox)

	var title := Label.new()
	title.name = "EventTitle"
	title.text = "❓ イベント"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	_vbox.add_child(title)

	var desc := RichTextLabel.new()
	desc.name = "EventDesc"
	desc.bbcode_enabled = true
	desc.fit_content = true
	desc.custom_minimum_size = Vector2(0, 90)
	desc.add_theme_font_size_override("normal_font_size", 16)
	_vbox.add_child(desc)

	_vbox.add_child(HSeparator.new())

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 10)
	_vbox.add_child(_choices_box)

	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.custom_minimum_size = Vector2(0, 60)
	_result_label.add_theme_font_size_override("normal_font_size", 16)
	_vbox.add_child(_result_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(spacer)

	_leave_btn = Button.new()
	_leave_btn.text = "出発する"
	_leave_btn.custom_minimum_size = Vector2(200, 48)
	_leave_btn.visible = false
	_leave_btn.pressed.connect(_on_leave)
	var leave_row := HBoxContainer.new()
	leave_row.alignment = BoxContainer.ALIGNMENT_CENTER
	leave_row.add_child(_leave_btn)
	_vbox.add_child(leave_row)

func _set_header(title: String, body: String) -> void:
	var t := _vbox.get_node("EventTitle") as Label
	t.text = title
	var d := _vbox.get_node("EventDesc") as RichTextLabel
	d.text = body

func _add_choice(label: String, handler: Callable, enabled: bool = true) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 52)
	btn.disabled = not enabled
	btn.pressed.connect(handler)
	_choices_box.add_child(btn)

func _resolve(result_text: String) -> void:
	if _resolved:
		return
	_resolved = true
	for child in _choices_box.get_children():
		child.queue_free()
	_result_label.text = result_text
	_leave_btn.visible = true

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

# ── Event Selection ───────────────────────────────────────────────

func _show_random_event() -> void:
	var events := [
		_event_treasure_chest,
		_event_healing_spring,
		_event_wandering_merchant,
		_event_wounded_traveler,
		_event_mysterious_altar,
	]
	var rng := GameState.run_rng
	var idx := rng.randi() % events.size()
	events[idx].call()

# ── Events ────────────────────────────────────────────────────────

func _event_treasure_chest() -> void:
	_set_header("📦 古びた宝箱",
		"道端に古びた宝箱が置かれている。鍵はかかっていないようだ。\n罠の可能性もあるが…どうする？")
	_add_choice("開ける（リスクあり）", _chest_open)
	_add_choice("そっとしておく", _chest_ignore)

func _chest_open() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.7:
		var gold := rng.randi_range(35, 70)
		GameState.collect_gold(gold)
		_resolve("[color=gold]宝箱には %d ゴールドが入っていた！[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.15)
		_resolve("[color=red]罠だ！毒矢が飛び出し、パーティ全員が %d ダメージを受けた…[/color]" % lost)

func _chest_ignore() -> void:
	_resolve("用心して宝箱には触れずに先へ進んだ。")

func _event_healing_spring() -> void:
	_set_header("💧 癒しの泉",
		"澄んだ水をたたえた泉を見つけた。神秘的な力が宿っているようだ。")
	_add_choice("水を飲む（HP回復）", _spring_hp)
	_add_choice("水を浴びる（MP回復）", _spring_mp)

func _spring_hp() -> void:
	var total := _heal_party_percent(0.40)
	_resolve("[color=lightgreen]泉の水を飲み、パーティ全員が合計 %d HP 回復した！[/color]" % total)

func _spring_mp() -> void:
	var total := _restore_party_mp_percent(0.50)
	_resolve("[color=aqua]泉の水を浴び、パーティ全員が合計 %d MP 回復した！[/color]" % total)

func _event_wandering_merchant() -> void:
	_set_header("🎲 彷徨う商人",
		"怪しげな商人が賭けを持ちかけてきた。\n「20ゴールドで、運が良ければ倍以上にして返そう…」")
	var can_afford := GameState.run_gold >= 20
	_add_choice("賭ける（20G）", _merchant_gamble, can_afford)
	if not can_afford:
		_add_choice("（ゴールドが足りない）", func() -> void: pass, false)
	_add_choice("立ち去る", _merchant_leave)

func _merchant_gamble() -> void:
	if not GameState.spend_run_gold(20):
		_resolve("ゴールドが足りなかった…")
		return
	var rng := GameState.run_rng
	var roll := rng.randf()
	if roll < 0.45:
		GameState.collect_gold(60)
		_resolve("[color=gold]大当たり！60 ゴールドを手にした！（差引 +40G）[/color]")
	elif roll < 0.75:
		GameState.collect_gold(20)
		_resolve("[color=yellow]引き分け。20 ゴールドが返ってきた。[/color]")
	else:
		_resolve("[color=red]はずれ…商人は笑いながら去っていった。（-20G）[/color]")

func _merchant_leave() -> void:
	_resolve("胡散臭い商人には関わらず先へ進んだ。")

func _event_wounded_traveler() -> void:
	_set_header("🩹 負傷した旅人",
		"傷ついた旅人が道端でうずくまっている。\n「すまない…薬を買う金もなくて…」")
	var can_afford := GameState.run_gold >= 15
	_add_choice("助ける（15G）", _traveler_help, can_afford)
	if not can_afford:
		_add_choice("（ゴールドが足りない）", func() -> void: pass, false)
	_add_choice("見て見ぬふりをする", _traveler_ignore)

func _traveler_help() -> void:
	if not GameState.spend_run_gold(15):
		_resolve("ゴールドが足りなかった…")
		return
	# Reward: a random item
	var item := _make_random_item()
	GameState.add_item(item)
	_resolve("[color=lightgreen]旅人は礼にと「%s」を譲ってくれた！[/color]\n(%s)" % [item.item_name, item.description])

func _traveler_ignore() -> void:
	var rng := GameState.run_rng
	var gold := rng.randi_range(5, 12)
	GameState.collect_gold(gold)
	_resolve("旅人を素通りした。道端に落ちていた %d ゴールドを拾った。" % gold)

func _event_mysterious_altar() -> void:
	_set_header("🗿 謎の祭壇",
		"古代の祭壇がある。「生命を捧げよ、さらば富を与えん」と刻まれている。")
	_add_choice("HPを捧げる（全員HP15%）", _altar_sacrifice)
	_add_choice("祈りを捧げる（無償）", _altar_pray)
	_add_choice("立ち去る", _altar_leave)

func _altar_sacrifice() -> void:
	var lost := _damage_party_percent(0.15)
	var gold := GameState.run_rng.randi_range(50, 90)
	GameState.collect_gold(gold)
	_resolve("[color=gold]祭壇が輝いた！%d ゴールドを得た。[/color]\n[color=red]（HPを合計 %d 失った）[/color]" % [gold, lost])

func _altar_pray() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var total := _heal_party_percent(0.20)
		_resolve("[color=lightgreen]祈りが通じた。柔らかな光がパーティを包み、合計 %d HP 回復した。[/color]" % total)
	else:
		_resolve("祈りを捧げたが、特に何も起こらなかった…")

func _altar_leave() -> void:
	_resolve("不気味な祭壇には近づかず立ち去った。")

# ── Effect Helpers ────────────────────────────────────────────────

func _heal_party_percent(percent: float) -> int:
	var total := 0
	for member: Character in GameState.party:
		if member.is_alive():
			total += member.heal(int(member.max_hp * percent))
	return total

func _restore_party_mp_percent(percent: float) -> int:
	var total := 0
	for member: Character in GameState.party:
		if member.is_alive():
			total += member.restore_mp(int(member.max_mp * percent))
	return total

func _damage_party_percent(percent: float) -> int:
	var total := 0
	for member: Character in GameState.party:
		if member.is_alive():
			var dmg: int = maxi(1, int(member.max_hp * percent))
			# Don't let an event kill a character — leave at least 1 HP.
			dmg = mini(dmg, member.current_hp - 1)
			if dmg > 0:
				member.current_hp -= dmg
				member.hp_changed.emit(member.current_hp, member.max_hp)
				total += dmg
	return total

func _make_random_item() -> ItemData:
	var item := ItemData.new()
	var roll := GameState.run_rng.randi() % 3
	match roll:
		0:
			item.item_name = "ポーション"
			item.description = "HPを80回復"
			item.item_type = ItemData.ItemType.HEAL_HP
			item.power = 80.0
		1:
			item.item_name = "エーテル"
			item.description = "MPを40回復"
			item.item_type = ItemData.ItemType.HEAL_MP
			item.power = 40.0
		_:
			item.item_name = "力の薬"
			item.description = "ATKを3ターン上昇"
			item.item_type = ItemData.ItemType.BUFF_ATK_TEMP
			item.power = 1.3
			item.duration = 3
	return item
