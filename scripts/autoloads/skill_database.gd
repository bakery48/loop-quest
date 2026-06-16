extends Node

## SkillDatabase — singleton. All SkillData definitions live here.

var all_skills: Array[SkillData] = []
var _by_rarity: Dictionary = {
	SkillData.Rarity.COMMON: [],
	SkillData.Rarity.RARE: [],
	SkillData.Rarity.LEGENDARY: [],
}

func _ready() -> void:
	_register_all()

# ── Public API ────────────────────────────────────────────────

func get_skill(skill_name: String) -> SkillData:
	for s in all_skills:
		if s.skill_name == skill_name:
			return s
	return null

## Returns `count` random SkillData usable by at least one class in party_class_ids.
## rarity_boost shifts probabilities toward RARE/LEGENDARY (used for elite battles).
func get_random_skill_rewards(count: int, rarity_boost: bool, party_class_ids: Array) -> Array[SkillData]:
	var pool: Array[SkillData] = []
	for skill in all_skills:
		if _usable_by_party(skill, party_class_ids):
			pool.append(skill)
	pool.shuffle()

	# Sort by desired rarity distribution
	var common_pool: Array[SkillData] = []
	var rare_pool: Array[SkillData] = []
	var legendary_pool: Array[SkillData] = []
	for s in pool:
		match s.rarity:
			SkillData.Rarity.COMMON: common_pool.append(s)
			SkillData.Rarity.RARE: rare_pool.append(s)
			SkillData.Rarity.LEGENDARY: legendary_pool.append(s)

	var result: Array[SkillData] = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for _i in range(count):
		var roll := rng.randf()
		var chosen: SkillData = null
		if rarity_boost:
			# Elite: 50% common, 35% rare, 15% legendary
			if roll < 0.50 and not common_pool.is_empty():
				chosen = common_pool.pick_random()
			elif roll < 0.85 and not rare_pool.is_empty():
				chosen = rare_pool.pick_random()
			elif not legendary_pool.is_empty():
				chosen = legendary_pool.pick_random()
		else:
			# Normal: 70% common, 25% rare, 5% legendary
			if roll < 0.70 and not common_pool.is_empty():
				chosen = common_pool.pick_random()
			elif roll < 0.95 and not rare_pool.is_empty():
				chosen = rare_pool.pick_random()
			elif not legendary_pool.is_empty():
				chosen = legendary_pool.pick_random()

		if chosen == null:
			# Fallback: any from pool
			if not pool.is_empty():
				chosen = pool.pick_random()

		if chosen and not chosen in result:
			result.append(chosen)

	return result

# ── Internals ─────────────────────────────────────────────────

func _usable_by_party(skill: SkillData, party_class_ids: Array) -> bool:
	if skill.allowed_classes.is_empty():
		return true
	for cid in party_class_ids:
		if cid in skill.allowed_classes:
			return true
	return false

func _add(skill: SkillData) -> void:
	all_skills.append(skill)
	_by_rarity[skill.rarity].append(skill)

func _make(sname: String, desc: String, mp: int, rarity: SkillData.Rarity,
		classes: Array, effect: SkillData.EffectType, power: float,
		duration: int = 0, tag: String = "", is_magic: bool = false) -> SkillData:
	var s := SkillData.new()
	s.skill_name = sname
	s.description = desc
	s.mp_cost = mp
	s.rarity = rarity
	s.allowed_classes.assign(classes)
	s.effect_type = effect
	s.power = power
	s.duration = duration
	s.special_tag = tag
	s.is_magic = is_magic
	return s

# ── Skill Definitions ─────────────────────────────────────────

func _register_all() -> void:
	_register_common_skills()
	_register_warrior_skills()
	_register_mage_skills()
	_register_cleric_skills()
	_register_thief_skills()
	_register_archer_skills()
	_register_monk_skills()
	_register_sage_skills()
	_register_hero_skills()

func _register_common_skills() -> void:
	# 挑発 — anyone
	_add(_make("挑発", "2ターン間、自身への攻撃確率UP",
		0, SkillData.Rarity.COMMON, [],
		SkillData.EffectType.STATUS_TAUNT, 1.0, 2))

	# かばう — anyone
	_add(_make("かばう", "指定した仲間が次に受けるダメージを代わりに受ける",
		4, SkillData.Rarity.COMMON, [],
		SkillData.EffectType.COVER_ALLY, 1.0, 1))

	# 反撃の構え — Warrior, Monk, Thief
	_add(_make("反撃の構え", "攻撃を受けたとき自動反撃（0.6倍）",
		6, SkillData.Rarity.COMMON, ["WARRIOR", "MONK", "THIEF"],
		SkillData.EffectType.STATUS_COUNTER, 0.6, 2))

	# 怒号 — Warrior, Hero, Monk
	_add(_make("怒号", "被攻撃確率UP＋次に受けるダメージ50%軽減",
		6, SkillData.Rarity.RARE, ["WARRIOR", "HERO", "MONK"],
		SkillData.EffectType.STATUS_TAUNT, 1.0, 2))

	# 集中 — Mage, Sage, Archer
	_add(_make("集中", "次の行動のダメージ・効果を1.5倍にする",
		8, SkillData.Rarity.COMMON, ["MAGE", "SAGE", "ARCHER"],
		SkillData.EffectType.BUFF_ATK, 1.5, 1))

func _register_warrior_skills() -> void:
	# 兜割り — Hero, Warrior, Monk
	_add(_make("兜割り", "1体に1.4倍の物理ダメージ。対象の防御力を1ターン低下",
		10, SkillData.Rarity.COMMON, ["HERO", "WARRIOR", "MONK"],
		SkillData.EffectType.DEBUFF_DEF, 1.4, 1))

	# 鉄壁の守り — Hero, Warrior, Monk, Cleric
	_add(_make("鉄壁の守り", "次に受けるダメージを大幅軽減",
		12, SkillData.Rarity.COMMON, ["HERO", "WARRIOR", "MONK", "CLERIC"],
		SkillData.EffectType.BUFF_SHIELD, 1.0, 1))

	# 怒りの爆発 — Warrior only (LEGENDARY)
	_add(_make("怒りの爆発", "蓄積ATKバフ量に応じた超大ダメージ。バフ全消費。",
		15, SkillData.Rarity.LEGENDARY, ["WARRIOR"],
		SkillData.EffectType.DAMAGE_SINGLE_CONDITIONAL, 2.5, 0, "consumes_warrior_stacks"))

func _register_mage_skills() -> void:
	# ファイアII — Mage, Sage, Summoner
	_add(_make("ファイアII", "敵1体または全体に火属性ダメージ",
		18, SkillData.Rarity.COMMON, ["MAGE", "SAGE", "SUMMONER"],
		SkillData.EffectType.DAMAGE_SINGLE, 1.8, 0, "", true))

	# メテオ — Mage, Sage (LEGENDARY)
	_add(_make("メテオ", "全体に超大ダメージ。高MPコスト",
		40, SkillData.Rarity.LEGENDARY, ["MAGE", "SAGE"],
		SkillData.EffectType.DAMAGE_ALL, 3.0, 0, "", true))

	# フロストノヴァ — Mage, Sage
	_add(_make("フロストノヴァ", "全体に氷属性ダメージ＋スロー付与",
		22, SkillData.Rarity.RARE, ["MAGE", "SAGE"],
		SkillData.EffectType.DAMAGE_ALL, 1.4, 0, "", true))

func _register_cleric_skills() -> void:
	# ヒール — Cleric, Hero
	_add(_make("ヒール", "味方1人のHPを大回復",
		16, SkillData.Rarity.COMMON, ["CLERIC", "HERO"],
		SkillData.EffectType.HEAL_SINGLE, 2.5, 0))

	# 全体回復 — Cleric
	_add(_make("全体回復", "パーティ全員のHPを中回復",
		30, SkillData.Rarity.RARE, ["CLERIC"],
		SkillData.EffectType.HEAL_ALL, 1.8, 0))

	# バリア — Cleric, Hero, Sage
	_add(_make("バリア", "味方1人に次のダメージを無効化するシールドを付与",
		14, SkillData.Rarity.RARE, ["CLERIC", "HERO", "SAGE"],
		SkillData.EffectType.BUFF_SHIELD, 1.0, 0))

func _register_thief_skills() -> void:
	# 影斬り — Thief, Hero (conditional)
	_add(_make("影斬り", "ダメージ2倍＋DEFデバフ。魔法使いATKバフ中に隠密状態でのみ発動",
		20, SkillData.Rarity.RARE, ["THIEF", "HERO"],
		SkillData.EffectType.DAMAGE_SINGLE_CONDITIONAL, 2.0, 0, "requires_stealth_and_mage_buff"))

	# 煙幕 — Thief
	_add(_make("煙幕", "自身が隠密状態になる",
		8, SkillData.Rarity.COMMON, ["THIEF"],
		SkillData.EffectType.STATUS_STEALTH, 1.0, 2))

	# 毒手 — Thief, Archer, Alchemist
	_add(_make("毒手", "敵1体に毒を付与（毎ターンHP減少）",
		10, SkillData.Rarity.COMMON, ["THIEF", "ARCHER", "ALCHEMIST"],
		SkillData.EffectType.DAMAGE_SINGLE, 0.8, 0))

func _register_archer_skills() -> void:
	# 貫通矢 — Archer, Thief (conditional)
	_add(_make("貫通矢", "照準精度3以上のとき発動。全体貫通ダメージ。精度全消費",
		16, SkillData.Rarity.RARE, ["ARCHER", "THIEF"],
		SkillData.EffectType.DAMAGE_SINGLE_CONDITIONAL, 1.6, 0, "requires_focus_3"))

	# スナイプ — Archer
	_add(_make("スナイプ", "照準中の敵に1.5倍ダメージ",
		12, SkillData.Rarity.COMMON, ["ARCHER"],
		SkillData.EffectType.DAMAGE_SINGLE, 1.5, 0))

func _register_monk_skills() -> void:
	# 覇王拳 — Monk only (LEGENDARY)
	_add(_make("覇王拳", "気ゲージ全消費。消費量×倍率ダメージ＋スタン",
		0, SkillData.Rarity.LEGENDARY, ["MONK"],
		SkillData.EffectType.DAMAGE_SINGLE_CONDITIONAL, 1.8, 0, "consumes_ki"))

	# 気功波 — Monk
	_add(_make("気功波", "気功型でのみ威力が上昇する遠距離攻撃",
		12, SkillData.Rarity.COMMON, ["MONK"],
		SkillData.EffectType.DAMAGE_SINGLE, 1.3, 0))

	# 瞑想 — Monk, Sage
	_add(_make("瞑想", "自身のHPとMPをわずかに回復",
		0, SkillData.Rarity.COMMON, ["MONK", "SAGE"],
		SkillData.EffectType.HEAL_SINGLE, 0.8, 0))

func _register_sage_skills() -> void:
	# 二重予言 — Sage only (LEGENDARY)
	_add(_make("二重予言", "次のターン、予言した技が2回発動。消費MP2倍",
		10, SkillData.Rarity.LEGENDARY, ["SAGE"],
		SkillData.EffectType.SPECIAL, 1.0, 0, "double_prophecy", true))

	# タイムストップ — Sage
	_add(_make("タイムストップ", "全敵に1ターンスタン",
		35, SkillData.Rarity.LEGENDARY, ["SAGE"],
		SkillData.EffectType.DAMAGE_ALL, 0.1, 0, "", true))

func _register_hero_skills() -> void:
	# バトルクライ — Hero
	_add(_make("バトルクライ", "パーティ全員のATKを2ターン上昇",
		16, SkillData.Rarity.RARE, ["HERO"],
		SkillData.EffectType.BUFF_ATK, 1.0, 2))
