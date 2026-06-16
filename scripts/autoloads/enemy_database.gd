extends Node

## EnemyDatabase — singleton.
## Holds all EnemyData definitions organised by chapter and tier.

## chapter (1-3) → Array[EnemyData]
var _normals: Dictionary = {}
## chapter (1-3) → Array[EnemyData]
var _elites: Dictionary = {}
## chapter (1-3) → EnemyData
var _bosses: Dictionary = {}

func _ready() -> void:
	_register_chapter1()
	_register_chapter2()
	_register_chapter3()

# ── Public API ────────────────────────────────────────────────

## Returns a randomised list of EnemyData for one encounter.
func get_encounter(chapter: int, is_elite: bool, is_boss: bool, rng: RandomNumberGenerator) -> Array[EnemyData]:
	if is_boss:
		var boss := get_boss(chapter)
		return [boss] if boss else []

	if is_elite:
		return _pick_elite_group(chapter, rng)

	return _pick_normal_group(chapter, rng)

func get_boss(chapter: int) -> EnemyData:
	return _bosses.get(chapter, null)

func get_normals(chapter: int) -> Array:
	return _normals.get(chapter, [])

func get_elites(chapter: int) -> Array:
	return _elites.get(chapter, [])

# ── Encounter Builders ────────────────────────────────────────

func _pick_normal_group(chapter: int, rng: RandomNumberGenerator) -> Array[EnemyData]:
	var pool: Array = _normals.get(chapter, [])
	if pool.is_empty():
		return []
	pool = pool.duplicate()
	pool.shuffle()
	# 2-3 enemies for normal encounter
	var count := rng.randi_range(2, 3)
	var out: Array[EnemyData] = []
	for i in range(mini(count, pool.size())):
		out.append(pool[i])
	return out

func _pick_elite_group(chapter: int, rng: RandomNumberGenerator) -> Array[EnemyData]:
	var pool: Array = _elites.get(chapter, [])
	if pool.is_empty():
		return _pick_normal_group(chapter, rng)  # fallback
	pool = pool.duplicate()
	pool.shuffle()
	# 1-2 elites
	var count := rng.randi_range(1, 2)
	var out: Array[EnemyData] = []
	for i in range(mini(count, pool.size())):
		out.append(pool[i])
	return out

# ── Builder Helpers ───────────────────────────────────────────

func _make(name: String, tier: EnemyData.EnemyTier, chapter: int,
		hp: int, atk: int, def_v: int, spd: int,
		gold_min: int, gold_max: int, stolen: bool = true) -> EnemyData:
	var d := EnemyData.new()
	d.enemy_name = name
	d.tier = tier
	d.chapter = chapter
	d.max_hp = hp; d.atk = atk; d.def_stat = def_v; d.spd = spd
	d.gold_min = gold_min; d.gold_max = gold_max
	d.can_be_stolen_from = stolen
	return d

func _action(name: String, type: EnemyAction.ActionType,
		power: float = 1.0, weight: float = 1.0, dur: int = 2) -> EnemyAction:
	var a := EnemyAction.new()
	a.action_name = name
	a.action_type = type
	a.power = power
	a.weight = weight
	a.duration = dur
	return a

func _add_normal(chapter: int, enemy: EnemyData) -> void:
	if not chapter in _normals:
		_normals[chapter] = []
	_normals[chapter].append(enemy)

func _add_elite(chapter: int, enemy: EnemyData) -> void:
	if not chapter in _elites:
		_elites[chapter] = []
	_elites[chapter].append(enemy)

func _set_boss(chapter: int, enemy: EnemyData) -> void:
	_bosses[chapter] = enemy

# ── Chapter 1: 平原 ───────────────────────────────────────────

func _register_chapter1() -> void:
	# ── Normal ──────────────────────────────────────
	var slime := _make("スライム", EnemyData.EnemyTier.NORMAL, 1, 45, 8, 2, 6, 4, 10)
	slime.actions = [
		_action("体当たり", EnemyAction.ActionType.ATTACK_SINGLE, 1.0, 3.0),
		_action("強打", EnemyAction.ActionType.ATTACK_SINGLE, 1.2, 1.0),
	]
	_add_normal(1, slime)

	var goblin := _make("ゴブリン", EnemyData.EnemyTier.NORMAL, 1, 38, 10, 3, 10, 5, 12)
	goblin.actions = [
		_action("なぐりつける", EnemyAction.ActionType.ATTACK_SINGLE, 1.0, 2.0),
		_action("防具を破る", EnemyAction.ActionType.DEBUFF_TARGET_DEF, 1.0, 1.0, 2),
	]
	_add_normal(1, goblin)

	var bandit := _make("野盗", EnemyData.EnemyTier.NORMAL, 1, 52, 9, 4, 8, 6, 14)
	bandit.actions = [
		_action("斬りつける", EnemyAction.ActionType.ATTACK_SINGLE, 1.0, 2.0),
		_action("気合を入れる", EnemyAction.ActionType.BUFF_SELF_ATK, 1.0, 1.0, 2),
	]
	_add_normal(1, bandit)

	var wolf := _make("草原オオカミ", EnemyData.EnemyTier.NORMAL, 1, 40, 11, 2, 13, 5, 11)
	wolf.actions = [
		_action("噛みつく", EnemyAction.ActionType.ATTACK_SINGLE, 1.0, 3.0),
		_action("力強い噛みつき", EnemyAction.ActionType.ATTACK_SINGLE, 1.3, 1.0),
	]
	_add_normal(1, wolf)

	# ── Elite ────────────────────────────────────────
	var goblin_captain := _make("ゴブリン隊長", EnemyData.EnemyTier.ELITE, 1, 95, 14, 6, 9, 18, 30)
	goblin_captain.actions = [
		_action("斬撃", EnemyAction.ActionType.ATTACK_SINGLE, 1.1, 2.0),
		_action("集団攻撃", EnemyAction.ActionType.ATTACK_ALL, 0.75, 1.0),
		_action("鼓舞する", EnemyAction.ActionType.BUFF_SELF_ATK, 1.0, 1.0, 2),
	]
	_add_elite(1, goblin_captain)

	var bandit_boss := _make("山賊頭", EnemyData.EnemyTier.ELITE, 1, 115, 13, 8, 7, 20, 35)
	bandit_boss.actions = [
		_action("重斬り", EnemyAction.ActionType.ATTACK_SINGLE, 1.4, 2.0),
		_action("鎧固め", EnemyAction.ActionType.BUFF_SELF_DEF, 1.0, 1.0, 3),
		_action("鎧砕き", EnemyAction.ActionType.DEBUFF_TARGET_DEF, 1.0, 1.0, 2),
	]
	_add_elite(1, bandit_boss)

	# ── Boss ─────────────────────────────────────────
	var gate_guardian := _make("砦の門番", EnemyData.EnemyTier.BOSS, 1, 320, 20, 11, 7, 80, 120, false)
	gate_guardian.enrage_hp_threshold = 0.35
	gate_guardian.boss_intro_message = "重厚な鎧に身を包んだ門番が剣を構えた！砦への道を阻む！"
	gate_guardian.actions = [
		_action("剣撃", EnemyAction.ActionType.ATTACK_SINGLE, 1.2, 3.0),
		_action("薙ぎ払い", EnemyAction.ActionType.ATTACK_ALL, 0.85, 1.0),
		_action("力を溜める", EnemyAction.ActionType.BUFF_SELF_ATK, 1.0, 1.0, 3),
		_action("守りを崩す", EnemyAction.ActionType.DEBUFF_TARGET_DEF, 1.5, 2.0, 2),
	]
	_set_boss(1, gate_guardian)

# ── Chapter 2: 洞窟 ───────────────────────────────────────────

func _register_chapter2() -> void:
	# ── Normal ──────────────────────────────────────
	var bat := _make("洞窟コウモリ", EnemyData.EnemyTier.NORMAL, 2, 55, 12, 4, 14, 8, 16)
	bat.actions = [
		_action("噛みつき", EnemyAction.ActionType.ATTACK_SINGLE, 1.0, 2.0),
		_action("毒噛み", EnemyAction.ActionType.APPLY_POISON, 0.4, 1.0, 3),
	]
	_add_normal(2, bat)

	var golem := _make("ロックゴーレム", EnemyData.EnemyTier.NORMAL, 2, 95, 17, 13, 5, 10, 18)
	golem.actions = [
		_action("岩拳", EnemyAction.ActionType.ATTACK_SINGLE, 1.0, 2.0),
		_action("岩石防御", EnemyAction.ActionType.BUFF_SELF_DEF, 1.0, 1.0, 3),
	]
	_add_normal(2, golem)

	var spider := _make("毒クモ", EnemyData.EnemyTier.NORMAL, 2, 50, 10, 5, 11, 8, 15)
	spider.actions = [
		_action("毒攻撃", EnemyAction.ActionType.APPLY_POISON, 0.5, 2.0, 3),
		_action("噛みつき", EnemyAction.ActionType.ATTACK_SINGLE, 0.9, 1.0),
		_action("防具溶かし", EnemyAction.ActionType.DEBUFF_TARGET_DEF, 1.0, 1.0, 2),
	]
	_add_normal(2, spider)

	var troll := _make("洞窟トロル", EnemyData.EnemyTier.NORMAL, 2, 78, 14, 8, 7, 9, 17)
	troll.actions = [
		_action("殴打", EnemyAction.ActionType.ATTACK_SINGLE, 1.0, 2.0),
		_action("傷の再生", EnemyAction.ActionType.HEAL_SELF, 0.15, 1.0),
	]
	_add_normal(2, troll)

	# ── Elite ────────────────────────────────────────
	var dark_knight := _make("ダークナイト", EnemyData.EnemyTier.ELITE, 2, 155, 21, 13, 8, 30, 50)
	dark_knight.actions = [
		_action("暗黒剣", EnemyAction.ActionType.ATTACK_SINGLE, 1.3, 2.0),
		_action("闇の力", EnemyAction.ActionType.BUFF_SELF_ATK, 1.0, 1.0, 3),
		_action("暗黒鎧", EnemyAction.ActionType.BUFF_SELF_DEF, 1.0, 1.0, 2),
	]
	_add_elite(2, dark_knight)

	var spider_queen := _make("毒蜘蛛の女王", EnemyData.EnemyTier.ELITE, 2, 135, 16, 9, 10, 28, 45)
	spider_queen.actions = [
		_action("猛毒噛み", EnemyAction.ActionType.APPLY_POISON, 0.8, 2.0, 4),
		_action("毒霧", EnemyAction.ActionType.ATTACK_ALL, 0.6, 1.0),
		_action("噛みつき", EnemyAction.ActionType.ATTACK_SINGLE, 0.9, 1.0),
	]
	_add_elite(2, spider_queen)

	# ── Boss ─────────────────────────────────────────
	var cave_giant := _make("洞窟の巨人", EnemyData.EnemyTier.BOSS, 2, 520, 26, 15, 6, 150, 200, false)
	cave_giant.enrage_hp_threshold = 0.40
	cave_giant.boss_intro_message = "地鳴りと共に、洞窟の奥から巨大な影が現れた！その咆哮が洞窟全体を揺らす！"
	cave_giant.actions = [
		_action("巨腕殴打", EnemyAction.ActionType.ATTACK_SINGLE, 1.5, 2.0),
		_action("大地震", EnemyAction.ActionType.ATTACK_ALL, 1.0, 1.0),
		_action("力溜め", EnemyAction.ActionType.BUFF_SELF_ATK, 1.0, 1.0, 3),
		_action("防御崩し", EnemyAction.ActionType.DEBUFF_TARGET_DEF, 1.0, 1.5, 2),
	]
	_set_boss(2, cave_giant)

# ── Chapter 3: 城塞 ───────────────────────────────────────────

func _register_chapter3() -> void:
	# ── Normal ──────────────────────────────────────
	var knight := _make("城塞騎士", EnemyData.EnemyTier.NORMAL, 3, 90, 19, 15, 9, 15, 25)
	knight.actions = [
		_action("斬撃", EnemyAction.ActionType.ATTACK_SINGLE, 1.2, 2.0),
		_action("鉄壁の守り", EnemyAction.ActionType.BUFF_SELF_DEF, 1.0, 1.0, 3),
	]
	_add_normal(3, knight)

	var mage_soldier := _make("魔法兵", EnemyData.EnemyTier.NORMAL, 3, 70, 22, 7, 12, 14, 22)
	mage_soldier.actions = [
		_action("魔法攻撃", EnemyAction.ActionType.ATTACK_SINGLE, 1.4, 1.0),
		_action("全体魔法", EnemyAction.ActionType.ATTACK_ALL, 0.9, 1.0),
		_action("防御崩し", EnemyAction.ActionType.DEBUFF_TARGET_DEF, 1.0, 1.0, 2),
	]
	_add_normal(3, mage_soldier)

	var dragon_rider := _make("火炎竜騎士", EnemyData.EnemyTier.NORMAL, 3, 85, 24, 10, 13, 16, 26)
	dragon_rider.actions = [
		_action("火炎剣", EnemyAction.ActionType.ATTACK_SINGLE, 1.1, 2.0),
		_action("炎の息吹", EnemyAction.ActionType.ATTACK_ALL, 0.8, 1.0),
	]
	_add_normal(3, dragon_rider)

	var trap_guard := _make("罠番兵", EnemyData.EnemyTier.NORMAL, 3, 75, 18, 11, 8, 13, 20)
	trap_guard.actions = [
		_action("打撃", EnemyAction.ActionType.ATTACK_SINGLE, 1.0, 2.0),
		_action("罠設置", EnemyAction.ActionType.DEBUFF_TARGET_DEF, 1.5, 2.0, 3),
	]
	_add_normal(3, trap_guard)

	# ── Elite ────────────────────────────────────────
	var archmage := _make("大魔導士", EnemyData.EnemyTier.ELITE, 3, 190, 28, 10, 11, 55, 80)
	archmage.actions = [
		_action("魔法砲", EnemyAction.ActionType.ATTACK_SINGLE, 1.6, 1.0),
		_action("全体呪文", EnemyAction.ActionType.ATTACK_ALL, 1.2, 1.0),
		_action("魔力解放", EnemyAction.ActionType.BUFF_SELF_ATK, 1.0, 2.0, 3),
	]
	_add_elite(3, archmage)

	var fortress_general := _make("城塞将軍", EnemyData.EnemyTier.ELITE, 3, 230, 26, 17, 8, 60, 90)
	fortress_general.actions = [
		_action("将軍の一撃", EnemyAction.ActionType.ATTACK_SINGLE, 1.4, 2.0),
		_action("武勇鼓舞", EnemyAction.ActionType.BUFF_SELF_ATK, 1.0, 1.0, 3),
		_action("鉄壁構え", EnemyAction.ActionType.BUFF_SELF_DEF, 1.0, 1.0, 3),
	]
	_add_elite(3, fortress_general)

	# ── Boss (Final) ─────────────────────────────────
	var demon_general := _make("魔王の将軍", EnemyData.EnemyTier.BOSS, 3, 850, 32, 20, 10, 250, 350, false)
	demon_general.enrage_hp_threshold = 0.40
	demon_general.boss_intro_message = "魔王の右腕たる将軍が魔剣を抜いた！この世界最後の希望が試される！"
	demon_general.actions = [
		_action("魔剣撃", EnemyAction.ActionType.ATTACK_SINGLE, 1.4, 2.0),
		_action("絶望の咆哮", EnemyAction.ActionType.ATTACK_ALL, 1.2, 1.0),
		_action("魔力増幅", EnemyAction.ActionType.BUFF_SELF_ATK, 1.0, 1.0, 4),
		_action("鉄壁破り", EnemyAction.ActionType.DEBUFF_TARGET_DEF, 2.0, 2.0, 3),
	]
	_set_boss(3, demon_general)
