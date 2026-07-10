extends Area3D

## LimbHitbox — Área de colisão para braços e pernas.
## Reduz o dano recebido pelo zumbi ao atingir essas áreas.

const LIMB_MULT := 0.5


func get_damage_multiplier() -> float:
	return LIMB_MULT
