local _, G = ...
PhyzGear = G
G.slots = {
    {1, "Head"}, {2, "Neck"}, {3, "Shoulders"}, {15, "Back"},
    {5, "Chest"}, {4, "Shirt"}, {19, "Tabard"}, {9, "Wrists"},
    {10, "Hands"}, {6, "Waist"}, {7, "Legs"}, {8, "Feet"},
    {11, "Finger"}, {12, "Finger"}, {13, "Trinket"}, {14, "Trinket"},
    {16, "Main hand"}, {17, "Off hand"}, {18, "Ranged"},
}
local optional = {[4]=true, [19]=true, [17]=true, [18]=true}
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
    local name, _, quality, level, required, _, subtype, _, loc, icon = C_Item.GetItemInfo(link)
    if not name then
        if C_Item.RequestLoadItemDataByID then
            local id = tonumber(link:match("item:(%d+)"))
            if id then C_Item.RequestLoadItemDataByID(id) end
        end
        return nil
    end
    return {name=name, quality=quality, level=level, required=required, subtype=subtype,
        loc=loc, icon=icon, link=link}
end
function G.Assess(slot, item, occupied, playerLevel)
    if optional[slot] then return "Optional", "This slot is cosmetic or depends on your weapon setup." end
    if not item then
        if occupied then return "Loading", "Waiting for item information." end
        return "Review", "No item equipped in this slot." end
    local required = G.Safe(item.required)
    if not required or required <= 0 then return "Unrated", "No useful required-level benchmark for this item." end
    local gap = math.max(10, math.floor(playerLevel * 0.25))
    if playerLevel - required >= gap then
        return "Review", ("Requires level %d; you are level %d. Check alternatives; this is not a power rating."):format(required, playerLevel)
    end
    return "No age flag", "Required level is within the review threshold. Stats may still warrant an upgrade."
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
function G.Candidates(equipped)
    local result = {}
    local locs = {
        [1]={INVTYPE_HEAD=true}, [2]={INVTYPE_NECK=true}, [3]={INVTYPE_SHOULDER=true},
        [15]={INVTYPE_CLOAK=true}, [5]={INVTYPE_CHEST=true,INVTYPE_ROBE=true},
        [9]={INVTYPE_WRIST=true}, [10]={INVTYPE_HAND=true}, [6]={INVTYPE_WAIST=true},
        [7]={INVTYPE_LEGS=true}, [8]={INVTYPE_FEET=true}, [11]={INVTYPE_FINGER=true},
        [12]={INVTYPE_FINGER=true}, [13]={INVTYPE_TRINKET=true}, [14]={INVTYPE_TRINKET=true},
        [16]={INVTYPE_WEAPON=true,INVTYPE_WEAPONMAINHAND=true,INVTYPE_2HWEAPON=true},
        [17]={INVTYPE_WEAPON=true,INVTYPE_WEAPONOFFHAND=true,INVTYPE_SHIELD=true,INVTYPE_HOLDABLE=true},
        [18]={INVTYPE_RANGED=true,INVTYPE_RANGEDRIGHT=true,INVTYPE_THROWN=true},
    }
    local sources = {}
    for _, record in pairs(G.catalogue) do sources[#sources+1] = record end
    for _, record in pairs(G.DB().sources) do sources[#sources+1] = record end
    for _, record in ipairs(sources) do
        local item = G.Item(record.link)
        if not item and record.metadata then
            item = {}
            for key, value in pairs(record.metadata) do item[key] = value end
            item.link = record.link
        end
        local level = G.Safe(UnitLevel("player")) or 1
        if item and locs[equipped.id] and locs[equipped.id][item.loc]
            and (item.required or 0) <= level and record.link ~= equipped.link
            and (not record.realm or record.realm == GetRealmName())
            and (not record.faction or record.faction == UnitFactionGroup("player")) then
            result[#result+1] = {item=item, source=record}
        end
    end
    table.sort(result, function(a,b)
        if (a.source.kind == "Database") ~= (b.source.kind == "Database") then
            return a.source.kind == "Database"
        end
        if a.item.level ~= b.item.level then return (a.item.level or 0) > (b.item.level or 0) end
        return a.item.name < b.item.name
    end)
    return result
end
local function Merchant()
    if not C_MerchantFrame or not C_MerchantFrame.GetItemInfo or not GetMerchantItemLink then return end
    local map = C_Map and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition(map, "player")
    local info = map and C_Map.GetMapInfo(map)
    local location = info and info.name or GetRealZoneText()
    if pos then location = ("%s (%.1f, %.1f)"):format(location, pos.x*100, pos.y*100) end
    for i=1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        local item = C_MerchantFrame.GetItemInfo(i)
        if link and item then
            G.Record({link=link, kind="Vendor", source=UnitName("npc") or "Visited vendor",
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
            G.Record({link=link,kind="Crafted",source=recipe.name or "Observed recipe",
                profession=profession and profession.professionName or "Profession not reported",
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
            G.Record({link=result.itemLink,kind="Auction",source="Observed auction " .. result.auctionID,
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
    if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then Merchant() end
    if event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_SHOW" then Crafts() end
    if event == "ITEM_SEARCH_RESULTS_UPDATED" then Auctions(...) end
    if event == "PLAYER_LOGIN" and G.CreateMinimap then G.CreateMinimap() end
    if G.Refresh then G.Refresh() end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
    "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW", "MERCHANT_UPDATE",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "ITEM_SEARCH_RESULTS_UPDATED"}) do
    pcall(events.RegisterEvent, events, event)
end
SLASH_PHYZGEAR1 = "/phyzgear"
SLASH_PHYZGEAR2 = "/pgear"
SlashCmdList.PHYZGEAR = function() G.Toggle() end
