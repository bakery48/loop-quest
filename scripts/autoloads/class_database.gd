extends Node

## ClassDatabase — singleton. All ClassData definitions live here.
## Access via ClassDatabase.find_class("WARRIOR") etc.

var _classes: Dictionary = {}

func _ready() -> void:
	_register_all()

func find_class(class_id: String) -> ClassData:
	return _classes.get(class_id, null)

func get_starter_classes() -> Array:
	var out: Array = []
	for c in _classes.values():
		if c.is_starter:
			out.append(c)
	return out

func get_all_classes() -> Array:
	return _classes.values()

# ── Registration ───────────────────────────────────────────────

func _register_all() -> void:
	_add(_make_hero())
	_add(_make_warrior())
	_add(_make_mage())
	_add(_make_cleric())
	_add(_make_thief())
	_add(_make_archer())
	_add(_make_monk())
	_add(_make_summoner())
	_add(_make_sage())
	_add(_make_alchemist())

func _add(data: ClassData) -> void:
	_classes[data.class_id] = data

func _base(class_id: String, name: String, type: ClassData.ClassType, starter: bool) -> ClassData:
	var d := ClassData.new()
	d.class_id = class_id
	d.display_name = name
	d.class_type = type
	d.is_starter = starter
	return d

func _make_hero() -> ClassData:
	var d := _base("HERO", "勇者", ClassData.ClassType.HERO, true)
	d.base_hp = 105; d.base_mp = 55; d.base_atk = 11; d.base_def = 7; d.base_spd = 10
	d.passive_name = "鼓舞のオーラ"
	d.passive_description = "毎ターン、パーティ全員のMPを少量回復する"
	d.unique_command_name = "連携"
	d.unique_command_description = "仲間1人にこのターン追加行動を付与する"
	d.unique_targets_ally = true
	return d

func _make_warrior() -> ClassData:
	var d := _base("WARRIOR", "戦士", ClassData.ClassType.WARRIOR, true)
	d.base_hp = 130; d.base_mp = 30; d.base_atk = 14; d.base_def = 9; d.base_spd = 8
	d.passive_name = "血の怒り"
	d.passive_description = "攻撃を受けるたびATKバフが累積する（最大5段）。バトル終了でリセット。"
	d.unique_command_name = "雄叫び"
	d.unique_command_description = "自身への被攻撃確率UP（挑発）＋ATKバフ1段階増加"
	return d

func _make_mage() -> ClassData:
	var d := _base("MAGE", "魔法使い", ClassData.ClassType.MAGE, true)
	d.base_hp = 70; d.base_mp = 90; d.base_atk = 9; d.base_def = 4; d.base_spd = 11
	d.passive_name = "詠唱慣性"
	d.passive_description = "前ターンに魔法スキルを使っているとATKバフ発動"
	d.unique_command_name = "静詠"
	d.unique_command_description = "スキルを使わずバフ状態を維持しながらMPを小回復"
	return d

func _make_cleric() -> ClassData:
	var d := _base("CLERIC", "僧侶", ClassData.ClassType.CLERIC, true)
	d.base_hp = 90; d.base_mp = 70; d.base_atk = 7; d.base_def = 7; d.base_spd = 8
	d.passive_name = "癒しのオーラ"
	d.passive_description = "毎ターン、HPが最も低い仲間を自動で微回復（最大HP8%）"
	d.unique_command_name = "加護"
	d.unique_command_description = "指定したキャラに中程度の回復＋DEFバフを付与"
	d.unique_targets_ally = true
	return d

func _make_thief() -> ClassData:
	var d := _base("THIEF", "盗賊", ClassData.ClassType.THIEF, false)
	d.base_hp = 85; d.base_mp = 45; d.base_atk = 12; d.base_def = 5; d.base_spd = 16
	d.passive_name = "電光石火"
	d.passive_description = "スキル使用が常に行動順最速（先制固定）"
	d.unique_command_name = "盗む"
	d.unique_command_description = "敵1体からランダムでアイテム・ゴールド・特殊アイテムを入手（成功率60%・1体1回）"
	d.unique_targets_enemy = true
	return d

func _make_archer() -> ClassData:
	var d := _base("ARCHER", "弓使い", ClassData.ClassType.ARCHER, false)
	d.base_hp = 80; d.base_mp = 40; d.base_atk = 11; d.base_def = 5; d.base_spd = 13
	d.passive_name = "狙撃眼"
	d.passive_description = "同一標的への連続攻撃で照準精度が蓄積（最大5段）。精度が高いほどダメージ上昇。"
	d.unique_command_name = "集中照準"
	d.unique_command_description = "標的を1体設定または切り替える。切り替えると精度リセット。"
	d.unique_targets_enemy = true
	return d

func _make_monk() -> ClassData:
	var d := _base("MONK", "武闘家", ClassData.ClassType.MONK, false)
	d.base_hp = 100; d.base_mp = 35; d.base_atk = 13; d.base_def = 7; d.base_spd = 12
	d.passive_name = "型の恩恵"
	d.passive_description = "攻撃型: ATK+30%/DEF-20% / 防御型: ダメージ-30%/被攻撃で気+1 / 気功型: MP-30%/気スキル解禁"
	d.unique_command_name = "型変え"
	d.unique_command_description = "型を順番に切り替える（攻撃型→防御型→気功型→繰り返し）"
	return d

func _make_summoner() -> ClassData:
	var d := _base("SUMMONER", "召喚士", ClassData.ClassType.SUMMONER, false)
	d.base_hp = 75; d.base_mp = 85; d.base_atk = 8; d.base_def = 5; d.base_spd = 9
	d.passive_name = "使役"
	d.passive_description = "召喚物が毎ターン自動で行動する"
	d.unique_command_name = "召喚"
	d.unique_command_description = "精霊を1体召喚する（最大2体同時展開）"
	return d

func _make_sage() -> ClassData:
	var d := _base("SAGE", "賢者", ClassData.ClassType.SAGE, false)
	d.base_hp = 75; d.base_mp = 100; d.base_atk = 9; d.base_def = 5; d.base_spd = 10
	d.passive_name = "千里眼"
	d.passive_description = "敵が次のターンに何をするか事前に確認できる"
	d.unique_command_name = "予言"
	d.unique_command_description = "任意のスキルを仕込む。次ターンに追加先制行動として発動（MPは今ターン消費）"
	return d

func _make_alchemist() -> ClassData:
	var d := _base("ALCHEMIST", "錬金術師", ClassData.ClassType.ALCHEMIST, false)
	d.base_hp = 80; d.base_mp = 60; d.base_atk = 9; d.base_def = 5; d.base_spd = 10
	d.passive_name = "素材採取"
	d.passive_description = "敵撃破時にランダム素材を1個入手（最大5個保持）"
	d.unique_command_name = "調合"
	d.unique_command_description = "素材を1つ消費し、指定アイテムをその場で即生成・即使用"
	return d
