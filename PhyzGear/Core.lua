local _, G = ...
PhyzGear = G
G.slots = {
    {1, "Head"}, {2, "Neck"}, {3, "Shoulders"}, {15, "Back"},
    {5, "Chest"}, {4, "Shirt"}, {19, "Tabard"}, {9, "Wrists"},
    {10, "Hands"}, {6, "Waist"}, {7, "Legs"}, {8, "Feet"},
    {11, "Finger"}, {12, "Finger"}, {13, "Trinket"}, {14, "Trinket"},
    {16, "Main hand"}, {17, "Off hand"}, {18, "Ranged"},
}
G.Wowhead = {name="Wowhead Forever", url="https://www.wowhead.com/forever/database"}
function G.ResearchURL(slot, link)
    local id = link and tonumber(link:match("item:(%d+)"))
    if id then return "https://www.wowhead.com/forever/item=" .. id end
    return "https://www.wowhead.com/forever/items/" .. (slot >= 16 and slot <= 18 and "weapons" or "armor")
end
-- Offline catalogue entries can carry verified metadata while the game cache loads.
-- Each imported record must include the exact Forever item page and verification date.
G.catalogue = {}
function G.ImportWowhead(records)
    local count = 0
    for _, record in ipairs(records or {}) do
        local id = tonumber(record.itemID)
        if id and record.name and record.loc and type(record.required) == "number"
            and type(record.level) == "number" and record.verified
            and record.url == "https://www.wowhead.com/forever/item=" .. id then
            G.catalogue[id] = {link="item:" .. id,kind="Database",source=G.Wowhead.name,
                url=record.url,verified=record.verified,metadata=record}
            count = count + 1
        end
    end
    if G.Refresh then G.Refresh() end
    return count
end
function G.Safe(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end
function G.DB()
    PhyzGearDB = PhyzGearDB or {}
    PhyzGearDB.sources = PhyzGearDB.sources or {}
    return PhyzGearDB
end
function G.Item(link)
    if not link or not C_Item or not C_Item.GetItemInfo then return nil end
    local name, _, quality, level, required, _, subtype, _, loc, icon, _, classID, subclassID, binding = C_Item.GetItemInfo(link)
    if not name then
        if C_Item.RequestLoadItemDataByID then
            local id = tonumber(link:match("item:(%d+)"))
            G.requestedItems=G.requestedItems or {}
            if id and (not G.requestedItems[id] or time()-G.requestedItems[id]>=30) then
                G.requestedItems[id]=time()
                C_Item.RequestLoadItemDataByID(id)
            end
        end
        return nil
    end
    return {name=name, quality=quality, level=level, required=required, subtype=subtype,
        loc=loc, icon=icon, link=link, classID=classID, subclassID=subclassID, binding=binding}
end
function G.Assess(slot, item, occupied, playerLevel)
    if slot == 4 or slot == 19 then return "Optional", "Cosmetic slot; excluded from gear assessment." end
    if (slot == 17 or slot == 18) and not occupied then
        return "Optional", "This empty slot depends on your weapon setup."
    end
    if not item then
        if occupied then return "Loading", "Waiting for item information." end
        return "Review", "No item equipped in this slot." end
    local required = G.Safe(item.required)
    if not required or required <= 0 then return "Unrated", "No useful required-level benchmark for this item." end
    local gap = math.max(10, math.floor(playerLevel * 0.25))
    if playerLevel - required >= gap then
        return "Review", ("Requires level %d; you are level %d. Check alternatives; this is not a power rating."):format(required, playerLevel)
    end
    return "Unrated", "No age concern found; this does not establish equipment strength."
end
function G.Equipment()
    local out = {}
    local level = G.Safe(UnitLevel("player")) or 1
    for _, slot in ipairs(G.slots) do
        local id = slot[1]
        local link = G.Safe(GetInventoryItemLink("player", id))
        local item = G.Item(link)
        local state, reason = G.Assess(id, item, link ~= nil, level)
        out[id] = {id=id, label=slot[2], link=link, item=item, state=state, reason=reason}
    end
    return out
end
function G.Stats(slot)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return "Hover for full details" end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
    if not ok or not data or not data.lines then return "Hover for full details" end
    local lines = {}
    for index, line in ipairs(data.lines) do
        local text = G.Safe(line.leftText)
        if index > 1 and type(text) == "string" and text:find("%d") then
            lines[#lines+1] = text
            if #lines == 2 then break end
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or "Hover for full details"
end
-- Providers must supply verified Forever records, not assumed Classic item tables.
-- Record: link, kind, source, profession, location, price, seen, realm, faction.
function G.Record(record)
    if not record.link or not record.kind or not record.source then return end
    local db = G.DB()
    local key = table.concat({record.kind, record.link, record.source, record.realm or "", record.faction or ""}, "|")
    db.sources[key] = record
end
local function Merchant()
    if not C_MerchantFrame or not C_MerchantFrame.GetItemInfo or not GetMerchantItemLink then return end
    local map = C_Map and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    local info = map and C_Map.GetMapInfo(map)
    local location = info and info.name or GetRealZoneText()
    if pos then location = ("%s (%.1f, %.1f)"):format(location, pos.x*100, pos.y*100) end
    local vendor = UnitName("npc") or "Visited vendor"
    G.sessionVendors = G.sessionVendors or {}
    G.sessionVendors[vendor .. "|" .. location] = true
    for i=1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        local item = C_MerchantFrame.GetItemInfo(i)
        if link and item then
            G.Record({link=link, kind="Vendor", source=vendor,
                location=location, price=item.price, quantity=item.stackCount,
                extendedCost=item.hasExtendedCost, seen=time(), realm=GetRealmName(),
                faction=UnitFactionGroup("player")})
        end
    end
end
local function Crafts()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs
        or not C_TradeSkillUI.GetRecipeItemLink or not C_TradeSkillUI.GetRecipeInfo then return end
    local profession = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    for _, id in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
        local recipe = C_TradeSkillUI.GetRecipeInfo(id)
        local link = C_TradeSkillUI.GetRecipeItemLink(id)
        if recipe and link then
            local personal = not (C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked())
                and not (C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild())
            local craftable = G.SafeCall and G.SafeCall(C_TradeSkillUI.GetCraftableCount,id)
            G.sessionCrafts=G.sessionCrafts or {}
            G.sessionCrafts[id]=personal and recipe.learned == true and type(craftable) == "number" and craftable>0 or false
            G.Record({link=link,kind="Crafted",source=recipe.name or "Observed recipe",
                profession=profession and profession.professionName or "Profession not reported",
                recipe=recipe.name,recipeID=id,
                canCraft=personal and recipe.learned == true and type(craftable) == "number" and craftable>0 or false,
                seen=time(),realm=GetRealmName(),faction=UnitFactionGroup("player")})
        end
    end
end
local function Auctions(key)
    if not key or not C_AuctionHouse or not C_AuctionHouse.GetItemSearchResultsQuantity
        or not C_AuctionHouse.GetItemSearchResultInfo then return end
    for i=1, C_AuctionHouse.GetItemSearchResultsQuantity(key) do
        local result = C_AuctionHouse.GetItemSearchResultInfo(key,i)
        if result and result.itemLink and result.buyoutAmount and result.buyoutAmount > 0 then
            local source="Observed auction " .. result.auctionID
            G.currentAuctionObservations=G.currentAuctionObservations or {}
            G.currentAuctionObservations[source]=true
            G.Record({link=result.itemLink,kind="Auction",source=source,
                price=result.buyoutAmount,quantity=result.quantity,seen=time(),realm=GetRealmName(),faction=UnitFactionGroup("player")})
        end
    end
end
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "PhyzGear" then G.DB() end
        return
    end
    -- Catalogue batches refresh the window every two seconds, not for each reply.
    if event=="GET_ITEM_INFO_RECEIVED" and G.Learner and G.Learner.pending[(...)] then return end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then Merchant() end
    if event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_SHOW" then Crafts() end
    if event == "ITEM_SEARCH_RESULTS_UPDATED" then Auctions(...) end
    if event == "PLAYER_LOGIN" and G.CreateMinimap then G.CreateMinimap() end
    if event == "PLAYER_LOGIN" and G.StartItemObservation then G.StartItemObservation() end
    if event == "PLAYER_LOGIN" and G.Learner then G.Learner.ResumeSaved() end
    if G.CollectOwnedItems and (event=="PLAYER_LOGIN" or event=="PLAYER_ENTERING_WORLD"
        or event=="PLAYER_EQUIPMENT_CHANGED" or event=="BAG_UPDATE_DELAYED") then
        G.CollectOwnedItems()
    end
    if G.InvalidateAdvisor then G.InvalidateAdvisor(event, ...) end
    if G.QueueRefresh then G.QueueRefresh() elseif G.Refresh then G.Refresh() end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
    "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW", "MERCHANT_UPDATE",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "ITEM_SEARCH_RESULTS_UPDATED",
    "PLAYER_MONEY", "QUEST_TURNED_IN", "SKILL_LINES_CHANGED", "TRAIT_CONFIG_UPDATED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "AUCTION_HOUSE_CLOSED", "BAG_UPDATE_DELAYED"}) do
    pcall(events.RegisterEvent, events, event)
end
SLASH_PHYZGEAR1 = "/phyzgear"
SLASH_PHYZGEAR2 = "/pgear"
SlashCmdList.PHYZGEAR = function(message)
    if G.AdvisorCommand and G.AdvisorCommand(message or "") then return end
    G.Toggle()
end
