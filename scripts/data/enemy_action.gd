class_name EnemyAction
extends Resource

enum ActionType {
	ATTACK_SINGLE,
	ATTACK_ALL,
	BUFF_SELF_ATK,
	BUFF_SELF_DEF,
	DEBUFF_TARGET_DEF,
	HEAL_SELF,
	SPECIAL,
}

@export var action_name: String = ""
@export var action_type: ActionType = ActionType.ATTACK_SINGLE
## Multiplier relative to enemy ATK/base value.
@export var power: float = 1.0
## Probability weight (relative). Normalized against all actions in the pool.
@export var weight: float = 1.0
## Duration for buff/debuff effects in turns.
@export var duration: int = 2
