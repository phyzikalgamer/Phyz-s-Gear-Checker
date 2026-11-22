# Phyz's Gear Checker

A character-style gear review addon for World of Warcraft: Forever (Interface 16001).

## Install

Download **PhyzGear-0.1.0.zip** from [Releases](https://github.com/phyzikalgamer/Phyz-s-Gear-Checker/releases). Extract the `PhyzGear` folder into your Forever `Interface/AddOns` folder and fully restart WoW. Open with the chest-armor minimap icon, `/pgear`, or `/phyzgear`. Drag the minimap icon to move it.

## Features

- Compact gear cards on both sides of a rotatable character model, with weapon slots beneath.
- Blizzard-style window and race-specific dressing-room backgrounds.
- Level-based review flags and full equipped-item hover tooltips.
- Slot options showing recorded vendor stock, profession recipe outputs, and observed auction buyouts with timestamps.
- Visible [Wowhead Forever](https://www.wowhead.com/forever/database) research links and support for attributed offline catalogue providers.

## Preview limitations

This first release has passed Lua syntax, manifest, Forever API-baseline, and ZIP checks but has not been tested in-game. Review flags are age hints, not stat-weight recommendations. No full Wowhead item catalogue is bundled: its equipment download returned HTTP 403. Vendor, crafting, and auction options are collected from observed data and need current-client verification. Auction listings can expire. Class proficiency and unique-equipped restrictions are not yet evaluated. Early Forever beta builds had SavedVariables persistence issues.

See [addon documentation](PhyzGear/README.md) for details and the in-game verification checklist.
