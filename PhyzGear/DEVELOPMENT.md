# Gear advisor implementation

## Audit and plan (22 November 2026)

The original addon contains Core.lua (equipment, age flags, observations and SavedVariables) and UI.lua (approved layout, model, backgrounds, minimap and slot overlay). PhyzGearDB.sources and minimapAngle must remain compatible. Candidates previously used item level alone, ignored proficiency and weapon interactions, and repeated the entire source scan. The header counted age flags as reviews. The installed client is 1.60.1.71037, Interface 16001; the bundled API baseline is older, build 69893, so its scanner is only a compatibility screen, not current-client runtime proof.

Implementation order: retain the overview; add an indexed data provider; add explicit character-scoped stat profiles and conservative comparisons; connect filters and comparisons to the existing overlay; test the pure Lua logic with mocked client APIs; install locally for in-game checks. No new authoritative weights or claims of best-in-slot.

## Data-source investigation

- [WoW Forever Knowledge Base](https://github.com/gBlaku/wow-forever-kb): accessible static exports, current metadata build 71037. Includes 22,838 items, of which 5,015 use Classic statistics. Its README identifies vmangos Classic loot and Classic proficiency assumptions. No top-level licence grants permission for its original processing code; upstream GPL data also needs provenance and licence handling. Do not bundle the aggregate or treat its loot as verified Forever drops. Potential research/cross-check source; exclude estimated records and require independently verified acquisition evidence.
- [Forever Guide](https://guide.wow4ever.se/en/api-docs): the public home page is accessible through web search, but the API documentation could not be fetched. Direct HTTPS retrieval failed certificate validation. No endpoint schema or redistribution grant was verified; no integration was fabricated and TLS validation was not disabled.
- [ForeverDB developers](https://foreverdb.net/developers): documented item, source, recipe, quest and instance endpoints; approved account/API key required. Rules explicitly permit fetching data and bundling it with releases, require attribution, and prohibit shipping keys. Distinguishes client, observed and Classic data. Recommended future upstream after access approval; no key is currently available. Import only confirmed Forever records, retain build/version and source verification independently.
- [Geared Forever](https://www.curseforge.com/wow/addons/gearedforever): GPLv3, describes build selection, source filters, actual random-enchantment stats, caps and race/talent handling. Useful architectural research; no code, database or weights copied. Its mathematical claims have not been independently validated here.
- [Wowhead Forever](https://www.wowhead.com/forever/database): keep visible research links. Bulk equipment retrieval previously returned HTTP 403. Links are not a packaged database.

## Recommended import architecture

Approved export → strict offline JSON validation → deterministic Lua generation → item/source provenance → slot indexes → level and restriction filtering → weighted comparisons → existing overlay. Each source needs independent Forever verification; verified item statistics do not establish a verified drop location. The importer accepts a documented normalized format, not arbitrary unverified upstream JSON. No third-party bulk database is bundled in this iteration. In-game vendor, profession and AH observations remain a separate provider. Fixtures used by tests are fictional and never loaded by the addon.

## Implemented scoring and interaction

- `Data.lua`: item-link and slot indexes, real client stats, pending-item resolution, source merging, cached metadata and provenance registration. Random-enchantment link variants remain distinct. No guessed stats, item names or loot.
- `Scoring.lua`: pure additive stat scoring and comparisons, two-hand replacement of both hands, selected-slot rings/trinkets, named per-character build profiles. No default speculative weights. Results are weighted points, never performance percentages. Ratings remain raw units selected by the user; no unverified conversion/cap formulas.
- `Advisor.lua`: class/level/usability checks, conservative unique/category filtering, source filters, quest-completion checks, positive-difference ranking, separate accessibility estimates and future filtering. Unsupported special effects/set interactions and incomplete weapon changes are excluded from automatic rankings. Talent APIs are not used to guess a build.
- `Options.lua`: existing overlay gains source buttons, two modes, future toggle, weights editor, selectable result rows, comparison/back, source details, and top-three dungeon/raid defaults. All new controls remain inside the existing window. Overview geometry, model, background, minimap and tooltips are preserved.
- `Core.lua`/`UI.lua`: extended collectors, separate header counts, debounced refreshes and event invalidation; retained existing SavedVariables. Profession readiness is tied to the current session and invalidated on bag changes.
- `Database.lua`: explicit empty approved-data provider, not a fabricated seed catalogue.
- `tools/gear/import_database.py`: deterministic offline generator; rejects unverified statistics/acquisition, estimated/Classic records, missing permission, duplicate IDs, conflicts, nonfinite/unsupported stats and unverified drop chances.
- `tools/gear/test_advisor.py`: Lua 5.1 runtime tests with mocked game APIs plus importer validation. Lupa is a development-only test dependency and is not packaged with the addon.

Auctionator's locally installed public API was inspected at `Source/API/v1/GetAuctionPrice.lua`, `GetAuctionAge.lua` and `README.md`. The optional bridge calls only its guarded read-only link-based price and age methods. Price age has day resolution; an exact timestamp is not synthesized. It never starts a search. Native AH observations are separately timestamped and lose session status when the AH closes.

## Remaining work and trust limits

The core upgrade pipeline and all source categories are implemented, but quest/dungeon/raid/broad profession coverage needs an approved, independently verified data export. No upstream key was requested or embedded. The current pipeline can compare previously observed items and approved provider records; it cannot discover an item absent from both.

The model is a configurable stat comparison, not a full Forever combat simulator. No validated spec presets, talent/racial coefficients, stat caps, diminishing returns, proc simulations, complete one-hand pair planner or set optimiser are supplied. These cannot safely be called authoritative without further data. `Good Equipment` and `Upgrade Recommended` are deliberately not asserted with incomplete coverage/model confidence; age reviews, potential improvements and unrated slots remain distinct. Profession materials/skill and quest/vendor prerequisites are shown if provided, but their complete availability is not inferred. Future proficiency depends on provider verification. Current equipability requires the client usability API; missing support yields exclusions rather than guesses.

## Validation

Tests run in an actual Lua 5.1 interpreter through Lupa with mocked APIs; this is not an in-game test. The suite covers low/mid/max levels, class restrictions, missing/secret stats, higher-item-level downgrades, lower-item-level upgrades, equal scores, two-hand changes, ring slots, unique categories, effects, multiple sources, completed quests, stale AH data, Auctionator integration, best/easiest ordering, async data, cache invalidation, top-three expansion, profile migration, importer rejection and UI wiring. Run it with `python tools/gear/test_advisor.py`.

The TOC validator and bundled Forever API scanner are additional static checks. Current-client gameplay, true API return behavior, all racial scenes, long/localized text, scrolling, recipe stock/craftability and SavedVariables restart persistence still require in-game verification. A full client restart is required because the file list changed.

The initial advisor passed 35 tests in Lua 5.1/Python. The v0.2.0 preset and pane updates expand that suite to 45 tests, including native-menu/fallback callbacks, preset isolation, all 28 guide references, correct ranged weapon scoring, and mouse-capture settings. All eight Lua modules parse and the TOC validates. The API-baseline scan reports zero missing unguarded globals, namespace functions or referenced Blizzard frames. This does not substitute for a current-client play test.

## v0.2.0 presets and pane refinement

`Presets.lua` adds manual spec selection and Recommended, Attack, Survivability and Custom modes with independently stored custom weights. The coefficients are explicitly addon-authored heuristics informed by the selected Wowhead Forever guide's stat categories, not weights published by Wowhead. Capped Hit/Expertise/Defense are not scored by these presets. All 28 class/spec references were checked on 22 November 2026; guide speculation and unsupported talent/weapon/school mechanics remain visible limitations. See [the full methodology](PRESETS.md).

The main equipment layout remains unchanged. The existing options overlay is now 440×680, remains within the main frame, replaces seven filter buttons with a source menu, groups spec/presets/sorting controls, and removes long generic paragraphs from the result list. The comparison view shows per-stat current/candidate values and acquisition details. Input capture is explicitly enabled on the pane, viewport, scroll content and editor to prevent click-through to covered gear cards. This mouse behavior still needs an actual client check.
