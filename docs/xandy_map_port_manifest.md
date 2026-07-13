# Inventário do port do mapa do Xandy

Origem auditada em 2026-07-12:

`C:\Users\Cadu\Downloads\outbreak_protocol-_pampa_2026-07-12_20-04-29\versao xandy`

## Arquivos de referência e SHA-256

| Conteúdo | SHA-256 |
|---|---|
| Cena original `src/scenes/node_3d.tscn` | `9AB3834189233A00C422923AD7F3889B32F37263E63900AABFC02A17F5506067` |
| HTerrain `assets/terrain/data.hterrain` | `318379402963975DF41E62DFDA9752FEF58250507772CC13CFFECBFE6A8A0604` |
| Fazenda `assets/Farm/farm.tscn` | `C47A0D03454DE99502B3D6F4470DEC071D4DED0CA0C622D4AFEF2B0BF3AB1DF0` |
| Açude `Assets_Scenes/açude.tscn` | `65E420CF0F8D5B38952141FCEB1039EE4BB9A8E67AAA0B02393E37BFF059B250` |
| Industrial `Assets_Scenes/industrial_exterior_v_2.tscn` | `57A2C01DF179C208744F6FB1C34B20024DD46631948CBF40E2CD4E59CC2E93EA` |
| Floresta original `Assets_Scenes/arvores.tscn` | `857269398BEC8C66C75BD7F57AED2840214A6C70228D092EF3477CE92D7A977B` |
| Limite invisível `Assets_Scenes/parede_invi.tscn` | `0949E0C78300218680C338B522F1927AE3D719CCD95C375B07A64BBA3CB3218D` |

## Escopo importado

- pacote completo do HTerrain, incluindo height, normal, color, detail e splat;
- 190 arquivos da fazenda, com cena, modelo e texturas;
- açude, complexo industrial, árvores, agrupamentos de colisão e paredes invisíveis;
- conteúdo ambiental da cena do Xandy convertido em `map_xandy_content.tscn`;
- floresta visual convertida de 1.050 nós de malha para 6 MultiMeshes;
- navegação externa refeita com 10.816 vértices, 17.982 polígonos e `agent_radius = 0.34`.

## Exclusões intencionais

O port não copiou `.godot`, `project.godot`, addons, scripts de gameplay, personagem, armas, sons, HUD, zumbis ou o spawner antigo. `node_3d.tscn` permanece responsável por multiplayer, jogadores, `GameSession`, `ZombieDirector`, navegação e carregamento.

## Colisões

`Arvere.tscn` agora contém somente um colisor cilíndrico de tronco. A malha visual vem exclusivamente dos MultiMeshes, evitando árvores duplicadas. As cenas sanitizadas do açude e do industrial substituem colisores côncavos por volumes simples válidos para o Jolt. A fazenda original permanece como referência visual porque a serialização achatada do asset contém dados de malha incompatíveis com o parser do Godot 4.6; os avisos côncavos desse asset continuam registrados para uma revisão visual dedicada no editor.
