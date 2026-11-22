# Guide-informed presets

Reviewed on 22 November 2026 against Wowhead's **Forever** stat-priority guides. Presets cover 28 selectable class/spec roles across the nine classes, including Cat and Bear separately. Guide URLs and check dates are stored in `Presets.lua`; choose **Guide source** in the panel to copy the selected guide's URL. These guides often describe endgame advice as provisional. A guide's priority per percentage point is not a numerical weight per raw rating.

## What the buttons mean

- **Recommended:** a balanced starting estimate using a subset of the chosen guide's main-stat/throughput priorities and a modest Stamina contribution. Tanks balance offensive stat contributions with Stamina and Armor. This is not a simulation or a complete reproduction of the guide's priority list.
- **Attack:** removes survival and regeneration contributions and favours offensive stats. For healer specs this intentionally becomes an offensive spell preset, not a healing-throughput preset.
- **Survivability:** Stamina and Armor only. It does not model effective health, avoidance, encounter damage or tank stat caps. This objective is an addon policy, not a Wowhead build recommendation.
- **Custom:** the existing saved personal weights. Selecting presets does not overwrite them; applying edits explicitly saves Custom.

Choose the intended spec yourself. The addon does not infer talent investment or silently pick the first spec. Presets are saved per character; unsupported classes retain Custom.

## Numerical policy and limits

**The coefficients are authored by Phyz for approximate sorting. They are not numeric weights published or endorsed by Wowhead.** Only the choice/grouping of some relevant stats is guide-informed. The model neither exactly reproduces the guide priority nor predicts DPS/healing.

The selected guide's focus groups receive 1, 0.6, 0.35, 0.2 and 0.1 points per raw stat (equal-tier groups share a coefficient). Crit and Haste ratings get small policy coefficients of 0.1 and 0.08. These are preference constants, not measured exchange rates. Recommended adds Stamina at 0.35; tank Recommended halves offensive contributions, then sets Stamina to 1 and Armor to 0.02. Survivability uses Stamina 1 and Armor 0.02. A ranged Hunter's Intellect uses a modest 0.25 resource preference without assuming Careful Aim's attack-power conversion.

Hit, Expertise and Defense are deliberately unweighted in presets because their caps and target/talent context are not modelled. School-specific damage, Spell Pierce, proc/set interactions, mana/healing spell coefficients, racials and talent scaling are also outside this preset model. Guides may prioritise these omitted stats; inspect them manually. Custom weights remain available for users with a validated model.

Weapon DPS has a policy coefficient of 2 only in supported weapon slots. Ranged Hunters use it only in the ranged slot. Physical/tank roles can use it in main hand, excluding Feral forms because no feral conversion is assumed. Speed, complete off-hand pair optimisation and hybrid weapon mechanics remain unsupported. Existing conservative effect, requirement and weapon-configuration exclusions still apply.

Some guides retain beta-era assumptions or disagree about caps. The source link lets the player inspect that context. This addon does not resolve those disagreements by inventing precise formulas.

## Panel changes

The main window geometry is unchanged. The existing overlay is wider (440 pixels) and stays inside the main window. Its toolbar groups spec/edit controls, preset buttons, source/sort menus and future/back controls. The list starts with a compact equipped summary; rows show estimated points and acquisition source. Selecting a row opens a stat-by-stat current/candidate comparison, then acquisition details. Long row text determines row height. The footer separates item provenance, guide provenance and database links.

The panel, scroll viewport, scroll content and weights editor explicitly capture mouse input. Background clicks should no longer select the gear cards behind the overlay. Runtime tests verify the input-capture settings and UI callbacks; actual pointer behavior still needs checking in-game.
