extends Area3D

## HeadHitbox — Área de colisão da cabeça do zumbi.
## O RayCast do player acerta este Area3D e chama take_damage_head().
## Repassa o dano ao CharacterBody3D pai com multiplicador de headshot.

const HEADSHOT_MULT := 3.0


func get_damage_multiplier() -> float:
	return HEADSHOT_MULT
