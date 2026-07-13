extends Area3D

## TorsoHitbox — Área de colisão do torso do zumbi.
## Dano normal (multiplicador 1.0).

const TORSO_MULT := 1.0


func get_damage_multiplier() -> float:
	return TORSO_MULT
