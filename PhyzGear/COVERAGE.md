# Coverage investigation — 22 November 2026

## Update in 0.3.0

The original audit below predates the independent client catalogue. The addon now discovers equipment IDs from local client metadata, then learns full statistics in bounded batches while the overview is open. It includes green gear and persists scan progress. No external bulk database is bundled. Actual learned coverage is installation-specific and can be checked with `/pgear scan status` and `/pgear debug coverage` (enable debug first). Successful loading does not establish where an item drops or that it is obtainable. See README for scan bounds, throttling and controls.

## Root cause and initial coverage

The deployed Database.lua contained **zero equipment records**. The inspected on-disk SavedVariables also contained **zero source observations and zero item snapshots**; only profile/minimap settings existed. Packaged valid-stat, acquisition and verified counts, and every slot/category/level count, were therefore all **0**. This explains the missing recommendations; it does not establish that the equipped gear has no upgrades. An on-disk snapshot may lag a running session until logout/reload.

Three gates compounded the problem: the importer required acquisition evidence for every item; RegisterDatabase indexed items only while iterating their sources; and the finder scored only items already having an eligible source. Even trustworthy source-less items were lost. A fourth gate excluded every passive Equip line, including ordinary static stat bonuses.

**No comprehensive external catalogue has been added by this repair.** The engine now evaluates client-observed or approved-provider item data independently of acquisition. It cannot discover arbitrary world loot absent from those pools.

## Public source investigation

[Knowledge Base](https://github.com/gBlaku/wow-forever-kb) JSON retrieval succeeded. Its metadata identifies build 1.60.1.71037, generated 2026-11-22 14:34 UTC. Findings from the actual export:

| Measure | Count |
|---|---:|
| Exported items | 22,838 |
| Weapon/armor equipment before visibility/estimate exclusions | 11,452 |
| Visible, non-estimated, non-junk combat equipment | 6,619 |
| Those with at least one numeric mapped combat stat | 6,107 |
| Those linked to an acquisition row | 4,423 |
| Acquisition rows with an explicit Forever-verification flag | 0 |

Zero explicit flags means verification is unknown, not that every source is false. Stat presence is not proof of complete effect accuracy. Client visibility is not proof of current-world availability. No reliable count of equipment exclusive to Forever can be established from this export.

| Slot | Records |
|---|---:|
| Head | 415 |
| Neck | 174 |
| Shoulder | 389 |
| Back | 264 |
| Chest/robe | 646 |
| Wrist | 459 |
| Hands | 559 |
| Waist | 576 |
| Legs | 536 |
| Feet | 620 |
| Finger | 284 |
| Trinket | 223 |
| One-hand | 290 |
| Main hand | 225 |
| Off hand | 13 |
| Two-hand | 383 |
| Shield | 155 |
| Held in off-hand | 162 |
| Ranged | 221 |
| Thrown | 25 |

Linked source rows: vendor 4,265; crafting 1,266; quest 1,536; creature drop 2,088; object 2,739; container 233. These are not unique items or verified Forever dungeon/raid counts. Required levels: none 1,955; 1–10 927; 11–20 431; 21–30 413; 31–40 394; 41–50 448; 51–60 2,034; above 60 17.

## Access, provenance and redistribution

- Knowledge Base mixes client statistics with Classic fallback statistics, loot and proficiency assumptions. No explicit aggregate redistribution licence was found in its repository/metadata. Its exports were used for private research/testing only; neither the aggregate data nor source code was bundled.
- [Forever Guide](https://guide.wow4ever.se/en/api-docs): API docs could not be fetched; direct HTTPS failed certificate validation. TLS checking was not disabled. No usable API/export permission was established.
- [ForeverDB](https://foreverdb.net/developers): documented item/source/recipe/quest/instance API, with approved access and attribution rules allowing release bundling. The user confirmed no approved access/export is currently available. No key was embedded.
- Installed QuestieDB's licence distinguishes historic contributions with unresolved rights. A Forever filename alone also does not verify every loot record. Its data was not copied.

**Incorporated data:** real local item facts read through C_Item/C_TooltipInfo from equipped items, bags and inspected tooltips. Existing observed vendor, recipe and AH sources remain separate and intact. No fabricated item, location, recipe, price or drop was introduced.

## Implemented changes

1. `Data.lua` registers and indexes verified items independently of sources, corrects changed slot indexes, retains random-enchantment links, and records item provenance. `PhyzGearDB.items` persists locally observed stats without replacing legacy settings/sources.
2. `import_database.py` accepts absent/empty acquisition lists. Restriction metadata can be incomplete: actual current-client usability remains mandatory; future items still need verified restrictions. Supplied unverified acquisition claims remain rejected.
3. `Advisor.lua` checks stats/compatibility/score before acquisition filtering. All returns source-less improvements as **Acquisition source unknown**. Specific acquisition filters do not use that fallback. BoE means potentially AH-obtainable, not listed now. Current bag ownership is labelled accurately.
4. Collection runs on login, equipment/bag changes, opening the overview and inspected item tooltips. It reads real stats, does not scan arbitrary item IDs, excludes non-equipment, and restores previous snapshots on later launches.
5. Passive Equip lines no longer blanket-block comparison; those rows explicitly warn that only represented stats are compared. Proc/use effects and set interactions remain conservative exclusions. This is not a full effect simulator.
6. Empty results now distinguish missing/empty database, no slot records, missing profile, missing current/candidate data, incompatible items, no better comparisons, unsupported comparisons and acquisition-filter exclusions. Successful source-less upgrades are distinct too.
7. `Diagnostics.lua` adds explicit developer reports and coverage counters. Normal gameplay produces no diagnostic chat. Lookup stays slot-indexed/cached; coverage enumeration is on demand.
8. Equipped hovers now use a dedicated tooltip without an automatic comparison pair. Replacement tooltips remain available. The interface geometry and visual design are unchanged.

## Diagnostics

```
/pgear debug on
/pgear debug report 1
/pgear debug coverage
/pgear debug off
```

Without a slot number, report uses the selected slot. It includes class/level, current item ID, scoring model/weights, database/slot candidates, slot mismatches, level/class/usability/restriction/data/effect exclusions, non-upgrades, acquisition filtering and final count. Output is bounded and explicit, not event-driven spam.

## After-repair count, validation and gaps

**Packaged external equipment remains 0.** The local usable count becomes the number of real items collected and validated on the user's client. A fixed post-install count cannot honestly be given before the client runs this version; `/pgear debug coverage` reports it. Previously observed items can now be compared without acquisition, and owned bag items require no external feed.

- **54 automated Lua 5.1/Python tests pass**, including source-less import/ranking, strict acquisition filters, bag capture, static passive stat comparisons, empty-state codes, diagnostics and the single equipped-tooltip path, alongside previous regression tests.
- Research-only validation used the **actual 6,619 non-estimated records** with simulated client responses. All 48 cases across Hunter/Mage/Warrior contexts, levels 10/20/35/60 and Head/Chest/Feet/Finger returned positive comparisons. Unknown sources stayed out of Vendor results. The harness took about 0.6 seconds. This is not an in-game benchmark, actual proficiency test, independent confirmation of availability or a bundled catalogue.
- All nine modules load in the runtime tests; TOC validation and the kit's API scan pass. Current-client behaviour still requires checking in-game. Fully restart WoW for the added module.

A permitted wider catalogue and verified acquisition information remain the material coverage gap. The repair makes trusted available item data usable; it does not disguise that gap by removing the warning alone.
