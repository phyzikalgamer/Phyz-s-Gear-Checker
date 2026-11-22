# Phyz's Gear Review — 0.3.2 preview

Gear overview and conservative upgrade research for WoW Forever, Interface 16001. The installed client was checked as 1.60.1.71037.

## Install and use

Copy `PhyzGear` into your Forever `Interface/AddOns` folder. Fully restart WoW after this update because the TOC adds modules. Open with `/pgear`, `/phyzgear`, or the draggable chest-armor minimap icon.

The approved layout is unchanged: top-aligned side equipment columns, three weapon cards at the top of the middle column, character beneath, centred yellow rotation hint, and clipped racial character-creation backdrop with dressing-room fallback. The frame is 1050 pixels wide; equipment cards are 272 pixels wide. Background and window assets come from Blizzard, not bundled art.

Select a slot to open the upgrades pane docked on the right. It follows the overview when dragged, and the combined layout scales to fit the screen. A framed item summary shows the rarity-coloured name and a small currently-equipped label. A gold divider separates controls from results.

The pane provides:

- Filter **All / Vendors / AH / Crafting / Quests / Dungeons / Raids**.
- Choose **Best Upgrade** (weighted point gain) or **Easiest Upgrade** (observed accessibility first, then point gain).
- Leave future items off to require current usability. Future items need verified class/proficiency metadata and show the level gap.
- Choose a spec, then **Recommended / Attack / Survivability / Custom**. The 28 guide-informed presets use approximate sorting coefficients authored by Phyz, not numeric Wowhead weights. **Guide source** copies the corresponding Forever guide URL. See [preset methodology](PRESETS.md).
- **Edit weights** saves a personal Custom profile. Click an item to see stat changes and known acquisition sources; use Back to return.
- Dungeon and raid lists show three by default, with Show more. Other lists show twenty by default.
- Source buttons select URLs for Ctrl+C and pasting into a browser. No HTTP requests occur inside WoW.

## Intended builds and scoring

No authoritative class weights are bundled. Select an intended spec and an estimated preset, or configure Custom; an unconfigured Custom build is Unrated. Presets leave capped Hit/Expertise/Defense unweighted and do not model talent/racial scaling. To keep distinct Custom profiles:

```
/pgear build My levelling build
/pgear weights agility=1 stamina=0.3
```

Those numbers are an input-format example, not a recommended Hunter profile. Profiles are per character and named build. The editor lists supported stats; `/pgear help` shows commands. Missing weights mean zero contribution. Primary stats, attack/spell power, raw hit/crit/haste/defence ratings, mitigation stats, MP5 and client-reported weapon DPS can be weighted. No conversion to performance percentages is made.

Score = sum(mapped client stat × selected weight). Only positive differences enter the ranked list. Two-hand candidates replace both equipped hands. One-hand swaps from a two-hander and off-hand swaps under a two-hander require a complete planned setup and are excluded. Rings/trinkets compare against the selected slot. Unique item/category conflicts are excluded conservatively. Set bonuses, procs and use/equip effects detected in item data are excluded from automatic ranking; detection cannot prove that every special mechanic has been found. Talent/racial conversions, caps, diminishing returns, weapon speed rotations and full gear-set optimisation are not modelled.

**Potential Upgrade** means a positive difference under your chosen model. **Review** is an empty core slot or a required-level age concern without a verified comparison. **Unrated** means scoring or coverage is insufficient. Shirt/tabard are Optional; empty off-hand/ranged slots remain setup-dependent. The header counts upgrades, age/empty reviews and unrated slots separately. No result establishes best-in-slot or an optimal item.

## Data and acquisition

No full third-party equipment database is bundled. See [the audit and source research](DEVELOPMENT.md). [Wowhead Forever](https://www.wowhead.com/forever/database) remains a visible research source. [ForeverDB](https://foreverdb.net/developers) is the recommended future approved feed; a developer key/export is not available in this build.

The [coverage investigation](COVERAGE.md) explains the empty original pool and the repair. Equipped gear, bag items and inspected item tooltips populate a separate client-verified item pool. **All** can compare trusted items with unknown acquisition; source-specific filters still require suitable evidence. Items currently in your bags are labelled as owned.

### Independent client catalogue

A dismissible notice appears only while scanning is active. It disappears when paused or finished. Dismissing hides the notice for the current login session without stopping the scan; the progress control remains available.

While the overview is open, the addon incrementally checks IDs 1–400,000 against the installed client's item-existence and instant equipment metadata APIs. Only locally recognised weapons/armor with equipment slots are queued; shirt/tabard are excluded. Greens are included. This bounded scan is not a claim of complete Forever coverage. The index can contain hidden or unavailable items; successful item loading confirms client statistics, not obtainable loot.

Full item requests are limited to two per 0.2-second tick (at most ten per second), with at most twenty outstanding. Cached records also enter the pool gradually. Requests time out after ten seconds and can be retried manually. Closing the window, clicking the progress text to pause, or entering combat stops new work. Progress, queued IDs, failures and learned snapshots persist account-wide on normal logout. A new client build restarts discovery and requeues prior observations. No other addon's code or item list is bundled.

The small progress button beneath the character shows learned records, queued items and index position. **100% index** means the bounded range was checked, not that all gear exists or every source is known. `/pgear scan status`, `/pgear scan pause`, `/pgear scan resume` and `/pgear scan retry` provide controls; the window must remain open to learn. Stats are attributed to **Local WoW Forever client**; Wowhead remains a research link. Expect the initial learning pass to take time, with suggestions appearing progressively. Unavailable records never become scored upgrades solely because their IDs exist.

- Visited vendor stock is recorded with vendor, map location/coordinates, recorded stack price, extra-cost flag and observation time. Coordinates are the player's position at the vendor. Requirements not reported by the client remain unknown.
- Profession windows record recipe outputs and profession. Craftability is only stated for a learned personal recipe with a positive API craftable count when observed. Skill requirements, materials and recipe unlocks require verified provider records; no recipes from other professions are invented.
- Item searches you initiate at the AH record buyout listings, quantities and observation times. This is a passive observer, not a scanner or buyer. Closing the AH clears session-only status. Recorded listings may already have sold.
- Bind-on-Equip items can appear as potentially AH-obtainable without a listing. If installed, Auctionator's public read-only price/age API supplies cached unit prices and age in days. These do not establish current availability or an exact observation timestamp; random variants may use Auctionator fallback pricing.
- Verified offline providers can supply vendors, crafting, quests, dungeon/raid loot, acquisition restrictions and provenance. Completed nonrepeatable quest sources are excluded when the completion API confirms them. Other prerequisite/choice/reputation restrictions are shown as supplied, not assumed satisfied. Drop rates require separate verification.

Legacy `PhyzGearDB.sources` and minimap settings are retained. Profiles live in `PhyzGearDB.characters[realm:name]`, and client item snapshots live in `PhyzGearDB.items`. The kit documented an early beta persistence bug; test actual persistence after a clean logout/restart on the current client.

## Offline database build

The repository's `tools/gear/import_database.py` accepts a normalized JSON bundle with schema 1, exact Forever game name, provider name/URL, build, licence, verification date, independently established redistribution permission, and items. Each item needs ID/name, INVTYPE location, item/required levels, mapped stats and `foreverVerified=true`. Acquisition records may be absent or empty. Restriction metadata is optional for current-client checks; future recommendations still need verified restrictions. Any supplied acquisition record needs a supported kind, source, HTTPS provenance URL, verification date and its own `foreverVerified=true`. Estimated/Classic-derived records, conflicts, duplicate IDs, nonfinite stats and unverified drop rates are rejected. It does not scrape arbitrary sites or ship keys.

```
python tools/gear/import_database.py verified-export.json PhyzGear/Database.lua
```

Generated Lua registers immutable offline records at load; slot indexes avoid full-database scans during redraw. Observed sources merge by item link, retaining random-enchantment variants. Importing a bare Wowhead research link does not establish acquisition evidence. Item data/candidate results are cached and invalidated on equipment, level, profile, item-load, talent, profession and acquisition changes. UI refreshes are coalesced.

## Validation and remaining checks

Run `python tools/gear/test_advisor.py` after installing Lupa in the local tools environment (or your Python environment). Tests use Lua 5.1 with mocked client APIs; fictional fixtures never ship in the addon. Tests cover filtering, scoring, weapons, rings, restrictions, source merging, stale prices, caching, async loading, importer validation and UI wiring. TOC validation and the kit's API-baseline scan are also required.

This advisor implementation has not been tested in-game. Enable `/console scriptErrors 1`; exercise empty/loaded slots, build setup, all filters, item comparison/back, tooltip hover, future mode, vendor/recipe/AH collection, equipment changes, level changes and persistence. Check long text, small UI scales and BugSack. Previous screenshots establish that the overview and racial background work on the user's client, not that the new advisor does.
