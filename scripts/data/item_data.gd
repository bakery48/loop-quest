class_name ItemData
extends Resource

enum ItemType {
	HEAL_HP,
	HEAL_MP,
	BUFF_ATK_TEMP,
	BUFF_DEF_TEMP,
	REVIVE,
	SPECIAL,
}

@export var item_name: String = ""
@export var description: String = ""
@export var item_type: ItemType = ItemType.HEAL_HP
## Heal/buff amount. For HP items: flat HP restored. For buffs: multiplier (e.g. 1.3 = +30% ATK).
@export var power: float = 50.0
## Duration in turns for buff items. 0 = instant.
@export var duration: int = 0
@export var targets_ally: bool = true
@export var targets_enemy: bool = false
