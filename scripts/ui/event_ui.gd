extends Control

## Random event node screen. Picks one event at random on entry.
## Each event is framed as a はい / いいえ question; one or both branches may
## lead to a follow-up 2-choice question, so a single event resolves through
## an effective 3-4 choice decision tree before returning to the map.

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
	desc.custom_minimum_size = Vector2(0, 110)
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

func _clear_choices() -> void:
	for child in _choices_box.get_children():
		_choices_box.remove_child(child)
		child.queue_free()

func _add_choice(label: String, handler: Callable, enabled: bool = true) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 52)
	btn.disabled = not enabled
	btn.pressed.connect(handler)
	_choices_box.add_child(btn)

## Presents a はい / いいえ question.
func _ask_yes_no(question: String, on_yes: Callable, on_no: Callable,
		yes_label: String = "はい", no_label: String = "いいえ",
		yes_enabled: bool = true) -> void:
	_clear_choices()
	if question != "":
		var d := _vbox.get_node("EventDesc") as RichTextLabel
		d.text = d.text + "\n\n[b]%s[/b]" % question
	_add_choice("⭕ " + yes_label, on_yes, yes_enabled)
	_add_choice("❌ " + no_label, on_no)

## Presents a follow-up 2-choice question (replaces the description body).
func _ask_two(title: String, body: String,
		label_a: String, on_a: Callable,
		label_b: String, on_b: Callable,
		a_enabled: bool = true, b_enabled: bool = true) -> void:
	_set_header(title, body)
	_clear_choices()
	_add_choice(label_a, on_a, a_enabled)
	_add_choice(label_b, on_b, b_enabled)

func _resolve(result_text: String) -> void:
	if _resolved:
		return
	_resolved = true
	_clear_choices()
	_result_label.text = result_text
	_leave_btn.visible = true

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

# ── Event Selection ───────────────────────────────────────────────

func _show_random_event() -> void:
	var events := [
		_event_treasure_chest,
		_event_healing_spring,
		_event_old_hermit,
		_event_monster_cub,
		_event_fallen_hero_grave,
		_event_bandit_ambush,
		_event_fortune_teller,
		_event_cursed_statue,
		_event_ruined_tavern,
		_event_thunder_god_trial,
		_event_suspicious_egg,
		_event_wishing_well,
	]
	var rng := GameState.run_rng
	var idx := rng.randi() % events.size()
	events[idx].call()

# ── 📦 古びた宝箱 ─────────────────────────────────────────────────

func _event_treasure_chest() -> void:
	_set_header("📦 古びた宝箱",
		"道端に古びた宝箱が置かれている。\nほんのり魔力を感じる…罠かもしれない。")
	_ask_yes_no("宝箱を開けてみるか？", _chest_yes, _chest_no)

func _chest_yes() -> void:
	_ask_two("📦 古びた宝箱",
		"近づくと、宝箱には頑丈な錠前がかかっていた。",
		"💪 力ずくでこじ開ける", _chest_force,
		"🔍 慎重に鍵穴を調べる", _chest_careful)

func _chest_force() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.6:
		var gold := rng.randi_range(45, 80)
		GameState.collect_gold(gold)
		_resolve("[color=gold]バキッ！錠前を破壊して開けると、%d ゴールドが入っていた！[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.15)
		_resolve("[color=red]無理にこじ開けた瞬間、毒針が飛び出した！\nパーティ全員が合計 %d ダメージを受けた…[/color]" % lost)

func _chest_careful() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.85:
		var gold := rng.randi_range(25, 50)
		GameState.collect_gold(gold)
		_resolve("[color=gold]慎重に罠を解除して開けた。%d ゴールドを安全に手に入れた。[/color]" % gold)
	else:
		_resolve("[color=yellow]鍵穴を調べているうちに、中身が空だと気づいた。\n誰かに先を越されていたようだ…[/color]")

func _chest_no() -> void:
	_resolve("用心して宝箱には触れずに先へ進んだ。\n君子危うきに近寄らず、だ。")

# ── 💧 癒しの泉 ───────────────────────────────────────────────────

func _event_healing_spring() -> void:
	_set_header("💧 癒しの泉",
		"澄んだ水をたたえた泉を見つけた。\n神秘的な力が宿っているようだ。")
	_ask_yes_no("泉の力を借りるか？", _spring_yes, _spring_no)

func _spring_yes() -> void:
	_ask_two("💧 癒しの泉",
		"泉の水は虹色に輝いている。どう使う？",
		"🩸 水を飲む（HP回復）", _spring_hp,
		"✨ 水を浴びる（MP回復）", _spring_mp)

func _spring_hp() -> void:
	var total := _heal_party_percent(0.45)
	_resolve("[color=lightgreen]泉の水を飲み、パーティ全員が合計 %d HP 回復した！[/color]" % total)

func _spring_mp() -> void:
	var total := _restore_party_mp_percent(0.55)
	_resolve("[color=aqua]泉の水を浴び、パーティ全員が合計 %d MP 回復した！[/color]" % total)

func _spring_no() -> void:
	_resolve("「うまい話には裏がある」と泉には近づかなかった。")

# ── 🧙 老仙人の問い ───────────────────────────────────────────────

func _event_old_hermit() -> void:
	_set_header("🧙 老仙人の問い",
		"洞窟の前に白髪の老人が座っている。\n「旅人よ、我の問いに答える勇気はあるか？」")
	_ask_yes_no("問いに答えるか？", _hermit_yes, _hermit_no)

func _hermit_yes() -> void:
	_ask_two("🧙 老仙人の問い",
		"「"力なき正義"と"正義なき力"…\nより危険なのはどちらだと思う？」",
		"⚖️ 力なき正義", _hermit_justice,
		"🗡️ 正義なき力", _hermit_power)

func _hermit_justice() -> void:
	var total := _heal_party_percent(0.25)
	_resolve("[color=lightgreen]「ほほう…謙虚な答えよのう」\n老人は微笑み、光を放った。HP +%d 回復した。[/color]" % total)

func _hermit_power() -> void:
	var gold := GameState.run_rng.randi_range(40, 65)
	GameState.collect_gold(gold)
	_resolve("[color=gold]「正しい！力こそが全てを決める！」\n老人は黄金の袋を投げてよこした。%d ゴールドを得た。[/color]" % gold)

func _hermit_no() -> void:
	var total := _restore_party_mp_percent(0.20)
	_resolve("[color=aqua]「無理にとは言わぬ。…だが、その慎重さも美徳よ」\n老人は静かに念を送ってくれた。MP +%d 回復。[/color]" % total)

# ── 🐾 魔物の子供 ─────────────────────────────────────────────────

func _event_monster_cub() -> void:
	_set_header("🐾 魔物の子供",
		"茂みの中から小さな魔物の子供が顔を出した。\n傷を負っていて、こちらをじっと見つめている…")
	_ask_yes_no("助けてやるか？", _cub_yes, _cub_no)

func _cub_yes() -> void:
	_ask_two("🐾 魔物の子供",
		"子供はおびえている。どう接する？",
		"💊 傷を手当てする", _cub_heal,
		"🍖 餌を分け与える", _cub_feed)

func _cub_heal() -> void:
	var item := _make_random_item()
	GameState.add_item(item)
	_resolve("[color=lightgreen]傷を癒してやると、嬉しそうに鳴いて走り去った。\n礼のつもりか「%s」を置いていった！[/color]" % item.item_name)

func _cub_feed() -> void:
	var total := _heal_party_percent(0.12)
	_resolve("[color=lightgreen]食べ物を差し出すと、ぺろぺろ舐めて喜んだ。\n不思議とこちらも元気が出てきた。HP +%d 回復。[/color]" % total)

func _cub_no() -> void:
	_resolve("関わり合いを避け、その場を立ち去った。\n子供の悲しげな鳴き声が背中に残った…")

# ── ⚔️ 英雄の墓 ───────────────────────────────────────────────────

func _event_fallen_hero_grave() -> void:
	_set_header("⚔️ 英雄の墓",
		"道端に立派な墓石がある。\n「ここに眠る英雄よ、汝の勇気は永遠なり」と刻まれている。")
	_ask_yes_no("墓に立ち寄るか？", _grave_yes, _grave_no)

func _grave_yes() -> void:
	_ask_two("⚔️ 英雄の墓",
		"墓の前に立った。どうする？",
		"🙏 静かに手を合わせる", _grave_pray,
		"⛏️ 副葬品がないか調べる", _grave_search)

func _grave_pray() -> void:
	var total := _restore_party_mp_percent(0.40)
	_resolve("[color=aqua]静かに手を合わせると、英雄の魂が語りかけてくる気がした。\n気力が満ちてきた。MP +%d 回復。[/color]" % total)

func _grave_search() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var gold := rng.randi_range(25, 45)
		GameState.collect_gold(gold)
		_resolve("[color=gold]墓の裏に布袋が隠されていた。%d ゴールドを得た。[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.15)
		_resolve("[color=red]墓を掘り返した瞬間、怨霊が飛び出した！\nパーティが合計 %d ダメージを受けた。罰当たりめ…[/color]" % lost)

func _grave_no() -> void:
	_resolve("英雄の眠りを妨げぬよう、黙礼して通り過ぎた。")

# ── 🗡️ 盗賊団の奇襲 ──────────────────────────────────────────────

func _event_bandit_ambush() -> void:
	_set_header("🗡️ 盗賊団の奇襲",
		"「動くな！金目のものを置いていけ！」\n茂みから武装した盗賊が飛び出してきた。")
	var can_pay := GameState.run_gold >= 25
	_ask_yes_no("大人しく金を払うか？（25G）", _bandit_pay, _bandit_refuse,
		"はい（払う）", "いいえ（払わない）", can_pay)

func _bandit_pay() -> void:
	if not GameState.spend_run_gold(25):
		_resolve("ゴールドが足りなかった…")
		return
	_resolve("25 ゴールドを差し出すと、盗賊たちは満足げに去っていった。\n悔しいが、無事に通り過ぎられた。")

func _bandit_refuse() -> void:
	_ask_two("🗡️ 盗賊団の奇襲",
		"「ほう、いい度胸だ！」\n盗賊が武器を構えた。どうする？",
		"⚔️ 正面から戦う", _bandit_fight,
		"💨 隙を突いて逃げる", _bandit_flee)

func _bandit_fight() -> void:
	var lost := _damage_party_percent(0.20)
	var gold := GameState.run_rng.randi_range(35, 60)
	GameState.collect_gold(gold)
	_resolve("[color=orange]激戦の末、盗賊を撃退した！合計 %d ダメージを受けたが、\n盗賊の財布から %d ゴールドを奪い返した！[/color]" % [lost, gold])

func _bandit_flee() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.6:
		_resolve("[color=lightgreen]全力で走り、なんとか逃げ切った！\n何も失わずに済んだ。[/color]")
	else:
		var lost := _damage_party_percent(0.12)
		_resolve("[color=red]背後から矢が飛んできた！\n逃げる途中でパーティが合計 %d ダメージを受けた。[/color]" % lost)

# ── 🔮 謎の占い師 ─────────────────────────────────────────────────

func _event_fortune_teller() -> void:
	_set_header("🔮 謎の占い師",
		"天幕の中に老婆の占い師がいる。\n「お前たちの未来が見える…代金はゴールド10枚じゃ」")
	var can_pay := GameState.run_gold >= 10
	_ask_yes_no("占ってもらうか？（10G）", _fortune_yes, _fortune_no,
		"はい（10G）", "いいえ", can_pay)

func _fortune_yes() -> void:
	if not GameState.spend_run_gold(10):
		_resolve("ゴールドが足りなかった…")
		return
	_ask_two("🔮 謎の占い師",
		"「何を占ってほしいんじゃ？」",
		"💰 金運を占う", _fortune_gold,
		"⚔️ 武運を占う", _fortune_battle)

func _fortune_gold() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.7:
		var gold := rng.randi_range(25, 45)
		GameState.collect_gold(gold)
		_resolve("[color=gold]「金運が巡ってきておる！ほれ、持っていきなさい」\n水晶玉から金貨が溢れ出た。%d ゴールドを得た！[/color]" % gold)
	else:
		_resolve("[color=yellow]「ふむ…今は時期が悪いようじゃ。無駄遣いは控えなされ」\n10ゴールド分の助言だけが残った。[/color]")

func _fortune_battle() -> void:
	var total := _restore_party_mp_percent(0.60)
	_resolve("[color=aqua]「次の戦い、勝機はある。気を研ぎ澄ませておけ」\n占い師の言葉で集中力が高まった。MP +%d 回復！[/color]" % total)

func _fortune_no() -> void:
	_resolve("占いなど信じない。自分の運命は自分で切り開く。")

# ── 😈 呪われた石像 ──────────────────────────────────────────────

func _event_cursed_statue() -> void:
	_set_header("😈 呪われた石像",
		"道の真ん中に宝石で飾られた石像がある。\nいかにも高そうだが「触れるな」と刻まれている…")
	_ask_yes_no("宝石を奪うか？", _statue_yes, _statue_no)

func _statue_yes() -> void:
	_ask_two("😈 呪われた石像",
		"宝石に手を伸ばすと、石像の目がほのかに光った。どうする？",
		"💎 構わず奪い取る", _statue_grab,
		"🧿 お守りを置いてから奪う", _statue_ward)

func _statue_grab() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var gold := rng.randi_range(60, 100)
		GameState.collect_gold(gold)
		_resolve("[color=gold]宝石を剥ぎ取った…何も起きなかった！\n%d ゴールド相当の宝石を手に入れた！[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.25)
		_resolve("[color=red]石像の目が真っ赤に光った！\n強烈な呪いでパーティが合計 %d ダメージを受けた！[/color]" % lost)

func _statue_ward() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.85:
		var gold := rng.randi_range(35, 60)
		GameState.collect_gold(gold)
		_resolve("[color=gold]お守りが呪いを吸収してくれた。\n安全に %d ゴールド分の宝石を手に入れた！[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.10)
		_resolve("[color=red]お守りでも防ぎきれない呪いだった…\nパーティが合計 %d ダメージを受けた。[/color]" % lost)

func _statue_no() -> void:
	var total := _heal_party_percent(0.10)
	_resolve("[color=lightgreen]注意書きに従い、静かに脇を通り過ぎた。\n何かに見守られている気がして、心が和んだ。HP +%d 回復。[/color]" % total)

# ── 🍺 廃墟の酒場 ─────────────────────────────────────────────────

func _event_ruined_tavern() -> void:
	_set_header("🍺 廃墟の酒場",
		"廃屋だと思っていたら、まだ営業中の酒場だった。\n老店主が一人、カウンターを磨いている。「客か、珍しいな」")
	_ask_yes_no("酒場に立ち寄るか？", _tavern_yes, _tavern_no)

func _tavern_yes() -> void:
	var can_rest := GameState.run_gold >= 20
	_ask_two("🍺 廃墟の酒場",
		"「さて、何にする？」",
		"🛏️ 宿泊する（20G・HP/MP大回復）", _tavern_rest,
		"💬 噂話を聞く（無料）", _tavern_info,
		can_rest, true)

func _tavern_rest() -> void:
	if not GameState.spend_run_gold(20):
		_resolve("ゴールドが足りなかった…")
		return
	var hp := _heal_party_percent(0.60)
	var mp := _restore_party_mp_percent(0.60)
	_resolve("[color=lightgreen]久しぶりの屋根の下での睡眠はありがたかった。\nHP +%d、MP +%d 回復！[/color]" % [hp, mp])

func _tavern_info() -> void:
	var tips := [
		"「この先には強い敵が出るらしい。装備は整えておきな」",
		"「ボスは正面より足元を狙うといいって噂だぞ」",
		"「焚き火ではよく旅人が一休みしていくらしい」",
		"「旅に出るなら仲間を大切にしな。一人じゃ生き残れん」",
	]
	var tip := tips[GameState.run_rng.randi() % tips.size()]
	_resolve("店主は手を止め、しばらく考えてから言った。\n[color=yellow]%s[/color]" % tip)

func _tavern_no() -> void:
	_resolve("怪しげな酒場には深入りせず、先を急いだ。")

# ── ⚡ 雷神の試練 ─────────────────────────────────────────────────

func _event_thunder_god_trial() -> void:
	_set_header("⚡ 雷神の試練",
		"空が突然曇り、天から声が響いた。\n「勇者よ、我は雷神なり。汝の勇気を試さん」")
	_ask_yes_no("試練を受けるか？", _thunder_yes, _thunder_no)

func _thunder_yes() -> void:
	_ask_two("⚡ 雷神の試練",
		"「ならば示せ。汝は誇り高き者か、慎ましき者か？」",
		"🔥 「恐れぬ！かかってこい！」", _thunder_brave,
		"🙇 「神よ、お導きを」と跪く", _thunder_kneel)

func _thunder_brave() -> void:
	var lost := _damage_party_percent(0.18)
	var hp := _heal_party_percent(0.45)
	_resolve("[color=orange]稲妻が降り注いだ！合計 %d ダメージ！\nしかし雷神の力が宿り、傷が癒えた。HP +%d 回復！\n「よき勇気よ。先へ進め！」[/color]" % [lost, hp])

func _thunder_kneel() -> void:
	var mp := _restore_party_mp_percent(0.80)
	_resolve("[color=aqua]「謙虚な者には恵みを授けよう」\n柔らかな雷光に包まれ、力が満ちた。MP +%d 回復！[/color]" % mp)

func _thunder_no() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var gold := rng.randi_range(45, 75)
		GameState.collect_gold(gold)
		_resolve("[color=gold]神を無視して歩き続けると、地面に金貨が落ちていた。%d ゴールド獲得。\n「…なかなかの豪胆者よ」と声がした気がした。[/color]" % gold)
	else:
		var lost := _damage_party_percent(0.18)
		_resolve("[color=red]「無礼者めが！」\n怒った雷神が稲妻を落とした！合計 %d ダメージ！[/color]" % lost)

# ── 🥚 謎の大きな卵 ──────────────────────────────────────────────

func _event_suspicious_egg() -> void:
	_set_header("🥚 謎の大きな卵",
		"道の真ん中に人の頭ほどの大きな卵が転がっている。\nほんのり温かく、中で何かが動いている気がする…")
	_ask_yes_no("卵を拾うか？", _egg_yes, _egg_no)

func _egg_yes() -> void:
	_ask_two("🥚 謎の大きな卵",
		"卵を抱え上げた。さて、どうする？",
		"🐣 温めて孵してみる", _egg_hatch,
		"💰 村で売り飛ばす", _egg_sell)

func _egg_hatch() -> void:
	var rng := GameState.run_rng
	var roll := rng.randi() % 3
	if roll == 0:
		var hp := _heal_party_percent(0.30)
		_resolve("[color=lightgreen]可愛らしい妖精が生まれた！\nお礼に癒しの粉を振りかけてくれた。HP +%d 回復！[/color]" % hp)
	elif roll == 1:
		var item := _make_random_item()
		GameState.add_item(item)
		_resolve("[color=lightgreen]スライムが生まれ、嬉しそうに跳ねて消えた。\n代わりに「%s」が残されていた。[/color]" % item.item_name)
	else:
		var lost := _damage_party_percent(0.12)
		_resolve("[color=red]小さなドラゴンが生まれ、いきなり炎を吐いた！\n合計 %d ダメージ！その後ケロッとした顔で飛び去った。[/color]" % lost)

func _egg_sell() -> void:
	var gold := GameState.run_rng.randi_range(40, 70)
	GameState.collect_gold(gold)
	_resolve("[color=gold]村で鑑定すると「珍しい魔物の卵だ」と言われ、\n%d ゴールドで買い取ってもらえた！[/color]" % gold)

func _egg_no() -> void:
	_resolve("「触らぬ神に祟りなし」と卵には手を出さなかった。")

# ── 🪙 願いの井戸 ─────────────────────────────────────────────────

func _event_wishing_well() -> void:
	_set_header("🪙 願いの井戸",
		"古い石造りの井戸がある。\n「コインを投げ入れれば願いが叶う」と言い伝えられているらしい。")
	var can_toss := GameState.run_gold >= 5
	_ask_yes_no("コインを投げ入れるか？（5G）", _well_yes, _well_no,
		"はい（5G）", "いいえ", can_toss)

func _well_yes() -> void:
	if not GameState.spend_run_gold(5):
		_resolve("ゴールドが足りなかった…")
		return
	_ask_two("🪙 願いの井戸",
		"コインが水面に消えた。何を願う？",
		"💪 体力の回復を願う", _well_health,
		"💰 富を願う", _well_wealth)

func _well_health() -> void:
	var hp := _heal_party_percent(0.30)
	var mp := _restore_party_mp_percent(0.30)
	_resolve("[color=lightgreen]井戸から温かい光が立ち昇った。\n願いが届いたのか、HP +%d、MP +%d 回復した！[/color]" % [hp, mp])

func _well_wealth() -> void:
	var rng := GameState.run_rng
	if rng.randf() < 0.5:
		var gold := rng.randi_range(20, 45)
		GameState.collect_gold(gold)
		_resolve("[color=gold]井戸の底がきらめき、コインが溢れ出した！%d ゴールド獲得！\n（差引でもプラスだ）[/color]" % gold)
	else:
		_resolve("[color=yellow]井戸はしんと静まり返ったまま…\nどうやら欲張りすぎたようだ。5ゴールドが無駄になった。[/color]")

func _well_no() -> void:
	_resolve("迷信は信じない、とそのまま井戸を後にした。")

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
