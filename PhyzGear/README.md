# Phyz's Gear Review — 0.1.0 development preview

Copy the `PhyzGear` folder into the Forever client's `Interface/AddOns` folder. Fully restart the client after installing. Open with `/pgear` or `/phyzgear`; Escape closes it.

You can also click the chest-armor minimap icon to open or close the window. Drag the icon around the minimap to reposition it; its angle is saved when client SavedVariables persistence is functioning.

Uses Blizzard's built-in window template, fonts, tooltips and PlayerModel, with compatibility checked against the community Forever addon kit bundled in this workspace. This kit is not an official Blizzard SDK. Interface 16001 comes from the kit's recorded Forever build; the installed client could not be located to confirm its current build.

The equipment overview follows the character sheet: eight cards on each side, player model in the middle, main hand/off hand/ranged underneath. Select a card to open a scrollable options overlay. Hover a card for its complete equipped tooltip. Drag the character to rotate it.

The window is 1050 pixels wide (5% wider than the initial preview). Equipment cards are 272 pixels wide (15% narrower); the extra room stays in the center. The interior uses Blizzard's racial dressing-room background texture tiles, selected from the character's race. Unknown races fall back to Human or Orc artwork by faction. The artwork paths follow Blizzard's [DressUpFrames source](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/DressUpFrames.lua). Texture availability and appearance still require in-game verification on Forever.

“Review” means an empty core slot or a required-level gap of at least max(10, 25% of player level). It is an age heuristic, not a stat-weight score. Zero-required-level items are unrated. Shirt, tabard, off hand and ranged slots are optional because cosmetics and weapon setups differ. Cards retain full tooltips; the two compact lines are numeric tooltip excerpts, not a full stat summary.

## Source collection

Default research source: [Wowhead Forever](https://www.wowhead.com/forever/database). The options panel shows attribution and provides Source link (equipped item), Database, and Slot items buttons. Each selects a URL in a copy field; press Ctrl+C and paste into a browser. WoW does not fetch website data. The public equipment-list download returned HTTP 403, so **no full Wowhead catalogue is bundled** and source links alone do not generate recommendations.

Verified offline records can be registered with `PhyzGear.ImportWowhead(records)` after Core.lua has loaded. Records require `itemID`, `name`, `loc` (INVTYPE token), numeric `required` and `level`, `verified` (date), and `url` exactly `https://www.wowhead.com/forever/item=ITEM_ID`. Optional fields include `quality`, `icon`, profession and acquisition details through the existing source provider. This API does not persist the catalogue: a provider must register its packaged data each load. Imported database candidates appear first; observed vendor, crafting and auction records follow. Each imported item displays its source URL and data verification date. Equipped stats continue to come from the game client.

- Visit vendors: record observed items, vendor name, zone and coordinates, stack price, additional-cost warning, and observation time. These are historical observations; stock is not guaranteed.
- Open professions: record recipe outputs and profession when available through the modern profession API. This does not establish that the player can craft the recipe, has its materials, or meets every requirement.
- Search individual equipment items at the auction house: record returned buyout listings, stack sizes and observation times through the modern auction API. This is a passive observer, not a full auction scan; cached listings may have sold. No automated searches or purchases.
- Other data providers can call `PhyzGear.Record({link=..., kind="Vendor"/"Crafted"/"Auction", source=..., profession=..., location=..., price=..., seen=time(), realm=..., faction=...})` with verified Forever evidence.

Only observed alternatives are listed, matched by equipment slot and required player level. They are sorted by item level, not declared upgrades. Class restrictions, armor proficiency, unique-equipped rules, weapon combinations, and stat weights are not yet evaluated. The full vendor/crafting database is not bundled. Auction and profession collectors require in-game verification on the user's current Forever client.

SavedVariables hold observations. The bundled kit reports an early beta persistence bug; persistence on the current build must be checked with a full logout and restart before trusting historical records.

## In-game checks still required

Enable `/console scriptErrors 1`, open `/pgear`, inspect loaded and empty slots, equip an item, level up, rotate the model, and open/close the options overlay. Visit a vendor with equippable gear, open a profession, then browse equipment auctions and check their records. Repeat after restarting. Test small UI scales and long localized item names. This preview has not been run in-game.
