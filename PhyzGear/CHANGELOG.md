# Changelog

## 0.3.2 preview

- Retain complete item-stat snapshots during catalogue item-load replies instead of clearing every item's cache.
- Do not evict complete client snapshots when recording repeat observations; incomplete data remains retryable.
- Keep equal-score/name results in a deterministic order and guard repeated docking layout calls.
- Equipment, level and proficiency changes still invalidate comparisons. 63 mocked runtime/import tests pass; live scan verification is required.

## 0.3.1 preview

- Dock the upgrades pane alongside the overview, with shared screen-fit scaling.
- Frame the equipped item with its rarity-coloured name, a smaller equipped label and a divider below controls.
- Show a dismissible notice only while catalogue scanning is active. Dismissal does not stop learning.
- 61 mocked runtime/import tests pass. Live layout verification remains required.

## 0.3.0 preview

- Independent item catalogue discovery using the installed Forever client's local item index, including uncommon gear.
- Bounded asynchronous item learning, saved progress, combat/closed-window pause, ten-second timeouts and manual retry.
- Visible learning progress and client-data attribution, separate from acquisition evidence and Wowhead research links.
- Source-less verified equipment can rank in All; acquisition filters retain their evidence requirements.
- Dedicated equipped tooltip, themed full-name header, smaller right-aligned status and working settings cog.
- 60 Lua 5.1 mocked runtime/import tests, TOC and API-baseline checks. In-game learning and performance still need validation.
