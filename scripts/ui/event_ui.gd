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
		_event_old_hermit,
		_event_monster_cub,
		_event_fallen_hero_grave,
		_event_bandit_ambush,
		_event_fortune_teller,
		_event_cursed_statue,
		_event_ruined_tavern,
		_event_thunder_god_trial,
		_event_suspicious_egg,
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

# ── 老仙人の問い ──────────────────────────────────────────────────

func _event_old_hermit() -> void:
	_set_header("🧙 老仙人の問い",
		"洞窟の前に白髪の老人が座っている。\n「旅人よ、我の問いに答えてみせよ。\n\n"力なき正義"と"正義なき力"、どちらが真に危険か？」")
	_add_choice("「力なき正義」と答える", _hermit_justice)
	_add_choice("「正義なき力」と答える", _hermit_power)
	_add_choice("「どちらも同じ」と答える", _hermit_both)

func _hermit_justice() -> void:
	var total := _heal_party_percent(0.25)
	_resolve("[color=lightgreen]「ほほう…謙虚な答えよのう」\n老人は微笑み、光を放った。パーティ全員のHPが合計 %d 回復した。[/color]" % total)

func _hermit_power() -> void:
	var gold := GameState.run_rng.randi_range(40, 60)
	GameState.collect_gold(gold)
	_resolve("[color=gold]「正しい！力こそが全てを決める！」\n老人は黄金の袋を放り投げた。%d ゴールドを得た。[/color]" % gold)

func _hermit_both() -> void:
	var total_hp := _heal_party_percent(0.15)
	var total_mp := _restore_party_mp_percent(0.30)
	_resolve("[color=aqua]「…ふむ、哲学者よのう」\n老人は眩しそうに笑い、すっと消えた。\nHP +%d、MP +%d 回復した。[/color]" % [total_hp, total_mp])

# ── 魔物の子供 ───────────────────────────────────────────────────

func _event_monster_cub() -> void:
	_set_header("🐾 魔物の子供",
		"茂みの中から小さな魔物の子供がひょっこり顔を出した。\n傷を負っているようで、こちらをじっと見つめている…")
	_add_choice("傷を手当てしてやる", _cub_heal)
	_add_choice("餌を与える（見逃す）", _cub_feed)
	_add_choice("追い払う", _cub_chase)

func _cub_heal() -> void:
	var item := _make_random_item()
	GameState.add_item(item)
	_resolve("[color=lightgreen]子供の傷を癒してやると、嬉しそうに鳴いて走り去った。\n礼のつもりか、光るものを置いていった。「%s」を入手！[/color]" % item.item_name)

func _cub_feed() -> void:
	var total := _heal_party_percent(0.10)
	_resolve("[color=lightgreen]食べ物を差し出すと、子供はぺろぺろ舐めて喜んだ。\n不思議なことに、見ているこちらも元気が出てきた。HP +%d 回復。[/color]" % total)

func _cub_chase() -> void:
	_resolve("子供は悲しそうな目でこちらを見ながら、森の奥へ走り去った。\n…なんだか後味が悪い。")

# ── 英雄の墓 ─────────────────────────────────────────────────────

func _event_fallen_hero_grave() -> void:
	_set_header("⚔️ 英雄の墓",
		"道端に立派な墓石がある。碑文には\n「ここに眠る英雄よ、汝の勇気は永遠なり」と刻まれている。\n傍らには枯れた花が供えられている。")
	_add_choice("碑文を読んで手を合わせる", _grave_pray)
	_add_choice("新しい花を供える（持っていれば）", _grave_flower)
	_add_choice("墓を調べる", _grave_search)

func _grave_pray() -> void:
	var total := _restore_party_mp_percent(0.40)
	_resolve("[color=aqua]静かに手を合わせると、英雄の魂が語りかけてくる気がした。\nパーティ全員の気力が満ちてきた。MP +%d 回復。[/color]" % total)

func _grave_flower() -> void:
	var gold := GameState.run_rng.randi_range(30, 50)
	GameState.collect_gold(gold)
	_resolve("[color=gold]花を供えると、地面から金色の光が溢れた。\n英雄のご加護か、%d ゴールドが現れた。[/color]" % gold)

func _grave_search() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var gold := rng.randi_range(20, 40)
		GameState.collect_gold(gold)
		_resolve("[color=gold]墓の裏に小さな石があった。持ち上げると布袋が出てきた。%d ゴールドを得た。[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.12)
		_resolve("[color=red]墓を掘り返そうとした瞬間、怨霊が飛び出してきた！\nパーティ全員が合計 %d ダメージを受けた。\nやめておけばよかった…[/color]" % lost)

# ── 盗賊団の奇襲 ─────────────────────────────────────────────────

func _event_bandit_ambush() -> void:
	_set_header("🗡️ 盗賊団の奇襲",
		"「動くな！金目のものを全部置いていけ！」\n茂みから武装した盗賊が3人飛び出してきた。")
	var can_pay := GameState.run_gold >= 25
	_add_choice("大人しく払う（25G）", _bandit_pay, can_pay)
	_add_choice("戦う構えを見せる（HP消費）", _bandit_fight)
	_add_choice("交渉する", _bandit_negotiate)

func _bandit_pay() -> void:
	if not GameState.spend_run_gold(25):
		_resolve("ゴールドが足りなかった…")
		return
	_resolve("25 ゴールドを差し出すと、盗賊たちは満足げに去っていった。\n悔しいが、無事に通り過ぎることができた。")

func _bandit_fight() -> void:
	var lost := _damage_party_percent(0.20)
	var gold := GameState.run_rng.randi_range(30, 55)
	GameState.collect_gold(gold)
	_resolve("[color=orange]激しい戦いの末、盗賊を撃退した！\nパーティが合計 %d ダメージを受けたが、\n盗賊から %d ゴールドを奪い返した！[/color]" % [lost, gold])

func _bandit_negotiate() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.4:
		var gold := rng.randi_range(10, 25)
		GameState.collect_gold(gold)
		_resolve("[color=lightgreen]「お前ら、腕は立つのか？仕事の話があるが…」\n依頼を断ると、盗賊は舌打ちしながら %d ゴールドを置いていった。[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.10)
		_resolve("[color=red]「口先だけの奴は嫌いだ！」\n交渉は決裂。不意打ちを受け、パーティが合計 %d ダメージを受けた。[/color]" % lost)

# ── 占い師 ───────────────────────────────────────────────────────

func _event_fortune_teller() -> void:
	_set_header("🔮 謎の占い師",
		"天幕の中に老婆の占い師がいる。\n「お前たちの未来が見える…代金はゴールド10枚じゃ」")
	var can_pay := GameState.run_gold >= 10
	_add_choice("占ってもらう（10G）", _fortune_pay, can_pay)
	_add_choice("タダで占ってもらおうとする", _fortune_cheat)
	_add_choice("断る", _fortune_refuse)

func _fortune_pay() -> void:
	if not GameState.spend_run_gold(10):
		_resolve("ゴールドが足りなかった…")
		return
	var rng := GameState.run_rng
	var fortunes := [
		"「次の戦いは厳しいが…諦めるな。勝機は必ずある」\n[color=lightgreen]パーティ全員の士気が上がった。MP 全回復！[/color]",
		"「金運が巡ってくるじゃろう。ほれ、これでも持っていきなさい」\n[color=gold]" + "+%d ゴールド！[/color]" % rng.randi_range(25, 45),
		"「道に迷う者がいるな…方角を教えよう」\n地図を広げ、隠し道を教えてもらった。[color=aqua]次のマスの情報が分かった気がした。[/color]",
		"「死相が出ておるぞ！お前たちは— 冗談じゃ冗談。\n[color=lightgreen]まあ元気出せ」HP 20%回復。[/color]",
	]
	var fortune := fortunes[rng.randi() % fortunes.size()]
	if "MP 全回復" in fortune:
		_restore_party_mp_percent(1.0)
	elif "+%d" in fortune:
		var gold := rng.randi_range(25, 45)
		GameState.collect_gold(gold)
	elif "HP 20%" in fortune:
		_heal_party_percent(0.20)
	_resolve("「見えたぞ、見えたぞ…」\n%s" % fortune)

func _fortune_cheat() -> void:
	var lost := _damage_party_percent(0.08)
	_resolve("[color=red]「無礼者！」\n老婆は怒り、呪いをかけてきた！\nパーティ全員が合計 %d ダメージを受けた。\nタダより高いものはない…[/color]" % lost)

func _fortune_refuse() -> void:
	_resolve("占いなどに頼る必要はない。自分の力を信じて先へ進んだ。")

# ── 呪われた石像 ─────────────────────────────────────────────────

func _event_cursed_statue() -> void:
	_set_header("😈 呪われた石像",
		"道の真ん中に奇妙な石像がある。\n宝石で飾られていて、いかにも高そうだが…\n「触れるな」という注意書きがある。")
	_add_choice("宝石を奪う（リスク大）", _statue_steal)
	_add_choice("注意書き通り触れずに通る", _statue_pass)
	_add_choice("石像を破壊する", _statue_destroy)

func _statue_steal() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var gold := rng.randi_range(60, 100)
		GameState.collect_gold(gold)
		_resolve("[color=gold]宝石を剥ぎ取ると…何も起きなかった！\n%d ゴールド相当の宝石を手に入れた！ラッキー！[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.25)
		_resolve("[color=red]石像の目が赤く光った！\n強烈な呪いが放たれ、パーティ全員が合計 %d ダメージを受けた！\n呪いには気をつけろ…[/color]" % lost)

func _statue_pass() -> void:
	var total := _heal_party_percent(0.08)
	_resolve("[color=lightgreen]注意書きに従い、静かに脇を通り過ぎた。\n何かに見守られている気がして、心が和んだ。HP +%d 回復。[/color]" % total)

func _statue_destroy() -> void:
	var rng := GameState.run_rng
	var lost := _damage_party_percent(0.12)
	var gold := rng.randi_range(15, 30)
	GameState.collect_gold(gold)
	_resolve("[color=orange]石像を叩き割ると、中から小袋が転がり出てきた！\n%d ゴールドを得たが、破壊の衝撃でパーティが合計 %d ダメージを受けた。[/color]" % [gold, lost])

# ── 廃墟の酒場 ───────────────────────────────────────────────────

func _event_ruined_tavern() -> void:
	_set_header("🍺 廃墟の酒場",
		"廃屋だと思っていたら、まだ営業中の酒場だった。\n老いた店主が一人、カウンターを磨いている。\n「久しぶりの客だ。何にする？」")
	var can_rest := GameState.run_gold >= 20
	var can_drink := GameState.run_gold >= 10
	_add_choice("宿泊して休む（20G・HP/MP大回復）", _tavern_rest, can_rest)
	_add_choice("酒を一杯飲む（10G）", _tavern_drink, can_drink)
	_add_choice("情報だけ聞く（無料）", _tavern_info)

func _tavern_rest() -> void:
	if not GameState.spend_run_gold(20):
		_resolve("ゴールドが足りなかった…")
		return
	var hp := _heal_party_percent(0.60)
	var mp := _restore_party_mp_percent(0.60)
	_resolve("[color=lightgreen]藁のベッドだったが、久しぶりの屋根の下での睡眠はありがたかった。\nHP +%d、MP +%d 回復！[/color]" % [hp, mp])

func _tavern_drink() -> void:
	if not GameState.spend_run_gold(10):
		_resolve("ゴールドが足りなかった…")
		return
	var rng := GameState.run_rng
	if rng.randf() < 0.6:
		var hp := _heal_party_percent(0.20)
		var mp := _restore_party_mp_percent(0.20)
		_resolve("[color=lightgreen]地元産の酒は芳醇な味わいで、体に活力が戻ってきた。\nHP +%d、MP +%d 回復！[/color]" % [hp, mp])
	else:
		var lost := _damage_party_percent(0.08)
		_resolve("[color=red]どうやらまずい銘柄を引いたらしい。\n腹を壊してパーティ全員が合計 %d ダメージを受けた…[/color]" % lost)

func _tavern_info() -> void:
	var tips := [
		"「この先には強い敵が出るらしい。装備は整えておきなさい」",
		"「ボスは正面から行くより、足元を狙うといいらしいぞ」",
		"「最近、焚き火ではよく旅人が一休みしていくらしい。癒されるんだとよ」",
		"「あそこの祭壇は本物じゃないって噂だがな。まあ、信じるかどうかは自由だ」",
		"「旅に出るなら、仲間は大切にしな。一人じゃ生き残れないからな」",
	]
	var tip := tips[GameState.run_rng.randi() % tips.size()]
	_resolve("店主は手を止め、しばらく考えてからこう言った。\n[color=yellow]%s[/color]" % tip)

# ── 雷神の試練 ───────────────────────────────────────────────────

func _event_thunder_god_trial() -> void:
	_set_header("⚡ 雷神の試練",
		"空が突然曇り、天から声が響いた。\n「勇者よ、我は雷神なり。汝の勇気を試さん。\n恐れず前に進む者か、それとも臆病者か？」")
	_add_choice("「恐れぬ！かかってこい！」と叫ぶ", _thunder_brave)
	_add_choice("「神よ、試練をお与えください」と跪く", _thunder_kneel)
	_add_choice("空を無視して歩き続ける", _thunder_ignore)

func _thunder_brave() -> void:
	var lost := _damage_party_percent(0.18)
	var hp := _heal_party_percent(0.40)
	_resolve("[color=orange]稲妻がパーティに降り注いだ！合計 %d ダメージ！\nしかし、雷神の力が体に宿り、傷がみるみる癒えていった。HP +%d 回復！\n「よき勇気よ。先へ進め！」[/color]" % [lost, hp])

func _thunder_kneel() -> void:
	var mp := _restore_party_mp_percent(0.80)
	_resolve("[color=aqua]「謙虚な者には恵みを授けよう」\n柔らかな雷光がパーティを包み、力が満ちてきた。\nMP +%d 回復！[/color]" % mp)

func _thunder_ignore() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var gold := rng.randi_range(50, 80)
		GameState.collect_gold(gold)
		_resolve("[color=gold]神など信じん、とばかりに歩き続けると…\n地面に金貨が落ちていた。%d ゴールドを拾った。\n「…なかなかの豪胆者よ」と声がした気がした。[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.20)
		_resolve("[color=red]「無礼者めが！」\n怒った雷神が稲妻を落とした！パーティ全員が合計 %d ダメージを受けた！\n神は敬うものだ…[/color]" % lost)

# ── 謎の卵 ───────────────────────────────────────────────────────

func _event_suspicious_egg() -> void:
	_set_header("🥚 謎の大きな卵",
		"道の真ん中に人の頭ほどもある大きな卵が転がっている。\nほんのり温かく、中で何かが動いている気がする…")
	_add_choice("温めて孵してあげる", _egg_hatch)
	_add_choice("卵を持ち帰る（売り飛ばす）", _egg_sell)
	_add_choice("割って中を見る", _egg_break)

func _egg_hatch() -> void:
	var rng := GameState.run_rng
	var outcomes := [
		func() -> String:
			var hp := _heal_party_percent(0.30)
			return "[color=lightgreen]可愛らしい妖精が生まれた！\nお礼に癒しの粉を振りかけてくれた。HP +%d 回復！[/color]" % hp,
		func() -> String:
			var item := _make_random_item()
			GameState.add_item(item)
			return "[color=lightgreen]大きなスライムが生まれ、嬉しそうに跳ねた後消えた。\n代わりに「%s」が残されていた。[/color]" % item.item_name,
		func() -> String:
			var lost := _damage_party_percent(0.12)
			return "[color=red]小さなドラゴンが生まれた！\nいきなり炎を吐いてきて、パーティが合計 %d ダメージを受けた！\nその後、ケロッとした顔で飛び去っていった。[/color]" % lost,
	]
	var fn: Callable = outcomes[rng.randi() % outcomes.size()]
	_resolve(fn.call())

func _egg_sell() -> void:
	var gold := GameState.run_rng.randi_range(40, 70)
	GameState.collect_gold(gold)
	_resolve("[color=gold]近くの村で卵を鑑定してもらうと「珍しい魔物の卵だ」と言われ、\n%d ゴールドで買い取ってもらえた！[/color]" % gold)

func _egg_break() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var hp := _heal_party_percent(0.25)
		_resolve("[color=lightgreen]中から黄金色の液体が溢れ出た。\n不思議な甘い香りがして、思わず口にすると……体が軽くなった！\nHP +%d 回復。[/color]" % hp)
	else:
		var lost := _damage_party_percent(0.10)
		_resolve("[color=red]中から真っ黒な煙が噴き出した！\n悪臭と毒気でパーティ全員が合計 %d ダメージを受けた…\n割らなければよかった。[/color]" % lost)

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
