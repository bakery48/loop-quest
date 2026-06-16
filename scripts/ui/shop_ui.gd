extends Control

const SKILL_PRICES: Dictionary = {
	SkillData.Rarity.COMMON: 50,
	SkillData.Rarity.RARE: 120,
	SkillData.Rarity.LEGENDARY: 250,
}
const ITEM_PRICE_MIN := 25
const ITEM_PRICE_MAX := 60

@onready var gold_label: Label = $VBox/Header/GoldLabel
@onready var skill_grid: HBoxContainer = $VBox/SkillSection/SkillGrid
@onready var item_grid: HBoxContainer = $VBox/ItemSection/ItemGrid
@onready var leave_btn: Button = $VBox/LeaveBtn

## Skill/item offerings generated once on entry.
var _skill_offers: Array[SkillData] = []
var _item_offers: Array = []  # Array of { item: ItemData, price: int }
var _skill_prices: Array[int] = []

func _ready() -> void:
	GameState.gold_changed.connect(_update_gold)
	leave_btn.pressed.connect(_on_leave)
	_generate_offers()
	_build_skill_grid()
	_build_item_grid()
	_update_gold(GameState.run_gold)

func _generate_offers() -> void:
	_skill_offers = SkillDatabase.get_random_skill_rewards(4, false, GameState.get_party_class_ids())
	_skill_prices.clear()
	for skill in _skill_offers:
		_skill_prices.append(SKILL_PRICES.get(skill.rarity, 50))

	_item_offers = []
	var rng := GameState.run_rng
	for i in range(3):
		var item := _make_random_item(rng)
		var price := rng.randi_range(ITEM_PRICE_MIN, ITEM_PRICE_MAX)
		_item_offers.append({ "item": item, "price": price })

func _make_random_item(rng: RandomNumberGenerator) -> ItemData:
	var item := ItemData.new()
	var roll := rng.randi() % 4
	match roll:
		0:
			item.item_name = "ポーション"; item.description = "HPを80回復"
			item.item_type = ItemData.ItemType.HEAL_HP; item.power = 80.0
		1:
			item.item_name = "エーテル"; item.description = "MPを40回復"
			item.item_type = ItemData.ItemType.HEAL_MP; item.power = 40.0
		2:
			item.item_name = "力の薬"; item.description = "ATKを3ターン上昇"
			item.item_type = ItemData.ItemType.BUFF_ATK_TEMP; item.power = 1.3; item.duration = 3
		3:
			item.item_name = "守りの薬"; item.description = "DEFを3ターン上昇"
			item.item_type = ItemData.ItemType.BUFF_DEF_TEMP; item.power = 1.3; item.duration = 3
	return item

func _build_skill_grid() -> void:
	for child in skill_grid.get_children():
		child.queue_free()

	for i in range(_skill_offers.size()):
		var skill := _skill_offers[i]
		var price := _skill_prices[i]
		var card := _make_skill_card(skill, price, i)
		skill_grid.add_child(card)

func _make_skill_card(skill: SkillData, price: int, index: int) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(180, 0)

	var rarity_colors := {
		SkillData.Rarity.COMMON: Color.WHITE,
		SkillData.Rarity.RARE: Color.CYAN,
		SkillData.Rarity.LEGENDARY: Color(1.0, 0.8, 0.2),
	}

	var name_lbl := Label.new()
	name_lbl.text = skill.skill_name
	name_lbl.modulate = rarity_colors.get(skill.rarity, Color.WHITE)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = _rarity_text(skill.rarity)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(rarity_lbl)

	var mp_lbl := Label.new()
	mp_lbl.text = "MP: %d" % skill.mp_cost
	card.add_child(mp_lbl)

	var classes_lbl := Label.new()
	classes_lbl.text = "対象: %s" % ("全員" if skill.allowed_classes.is_empty() else ", ".join(skill.allowed_classes))
	classes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(classes_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = skill.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "購入 %dG" % price
	buy_btn.disabled = GameState.run_gold < price
	buy_btn.pressed.connect(_on_buy_skill.bind(index, buy_btn))
	card.add_child(buy_btn)

	return card

func _build_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()

	for i in range(_item_offers.size()):
		var offer: Dictionary = _item_offers[i]
		var card := _make_item_card(offer.item, offer.price, i)
		item_grid.add_child(card)

func _make_item_card(item: ItemData, price: int, index: int) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(160, 0)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(desc_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "購入 %dG" % price
	buy_btn.disabled = GameState.run_gold < price
	buy_btn.pressed.connect(_on_buy_item.bind(index, buy_btn))
	card.add_child(buy_btn)

	return card

func _on_buy_skill(index: int, btn: Button) -> void:
	if index >= _skill_offers.size():
		return
	var skill := _skill_offers[index]
	var price := _skill_prices[index]
	if not GameState.spend_run_gold(price):
		return

	# Give to first party member who can equip it
	var recipient: Character = null
	for member in GameState.party:
		if member.can_equip_skill(skill):
			recipient = member
			break
	if recipient == null and not GameState.party.is_empty():
		recipient = GameState.party[0]
	if recipient:
		recipient.add_skill_to_inventory(skill)

	btn.text = "購入済み"
	btn.disabled = true

func _on_buy_item(index: int, btn: Button) -> void:
	if index >= _item_offers.size():
		return
	var offer: Dictionary = _item_offers[index]
	if not GameState.spend_run_gold(offer.price):
		return
	GameState.add_item(offer.item)
	btn.text = "購入済み"
	btn.disabled = true

func _update_gold(amount: int) -> void:
	gold_label.text = "所持ゴールド: %dG" % amount
	# Refresh all buy buttons
	_refresh_buy_buttons()

func _refresh_buy_buttons() -> void:
	# Easiest: rebuild both grids
	_build_skill_grid()
	_build_item_grid()

func _on_leave() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _rarity_text(rarity: SkillData.Rarity) -> String:
	match rarity:
		SkillData.Rarity.COMMON: return "コモン"
		SkillData.Rarity.RARE: return "レア"
		SkillData.Rarity.LEGENDARY: return "レジェンド"
	return ""
