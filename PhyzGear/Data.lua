local _, G = ...
local D = {byLink={}, byLoc={}, cache={}, pending={}, revision=0}
G.Data = D
G.StatTokens = {
    strength="ITEM_MOD_STRENGTH_SHORT", agility="ITEM_MOD_AGILITY_SHORT",
    stamina="ITEM_MOD_STAMINA_SHORT", intellect="ITEM_MOD_INTELLECT_SHORT",
    spirit="ITEM_MOD_SPIRIT_SHORT", armor="RESISTANCE0_NAME",
    attackPower="ITEM_MOD_ATTACK_POWER_SHORT", rangedAttackPower="ITEM_MOD_RANGED_ATTACK_POWER_SHORT",
    spellPower="ITEM_MOD_SPELL_POWER_SHORT", healing="ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    hit="ITEM_MOD_HIT_RATING_SHORT", crit="ITEM_MOD_CRIT_RATING_SHORT",
    haste="ITEM_MOD_HASTE_RATING_SHORT", defense="ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
    dodge="ITEM_MOD_DODGE_RATING_SHORT", parry="ITEM_MOD_PARRY_RATING_SHORT",
    block="ITEM_MOD_BLOCK_RATING_SHORT", blockValue="ITEM_MOD_BLOCK_VALUE_SHORT",
    expertise="ITEM_MOD_EXPERTISE_RATING_SHORT", mp5="ITEM_MOD_MANA_REGENERATION_SHORT",
    meleeHit="ITEM_MOD_HIT_MELEE_RATING_SHORT", spellHit="ITEM_MOD_HIT_SPELL_RATING_SHORT",
    rangedHit="ITEM_MOD_HIT_RANGED_RATING_SHORT", meleeCrit="ITEM_MOD_CRIT_MELEE_RATING_SHORT",
    spellCrit="ITEM_MOD_CRIT_SPELL_RATING_SHORT", rangedCrit="ITEM_MOD_CRIT_RANGED_RATING_SHORT",
    dps="ITEM_MOD_DAMAGE_PER_SECOND_SHORT",
}
function G.ItemKey(link)
    return type(link) == "string" and (link:match("|H(item:[^|]+)|h") or link) or nil
end
local function SafeCall(fn, ...)
    if not fn then return nil end
    local ok, value = pcall(fn,...)
    if ok then
        if type(value)=="table" and issecrettable and issecrettable(value) then return nil end
        return G.Safe(value)
    end
end
G.SafeCall = SafeCall
function D.Item(link)
    local key = G.ItemKey(link)
    if not key then return nil end
    if D.cache[key] then return D.cache[key] end
    local item = G.Item(link)
    local entry = D.byLink[key]
    local offline = entry and entry.metadata
    if not item and offline then
        item = {}
        for field,value in pairs(offline) do item[field] = value end
    end
    if not item then return nil end
    item.link = link
    item.id = tonumber(key:match("item:(%d+)"))
    item.stats = {}
    local raw = SafeCall(C_Item and C_Item.GetItemStats,link)
    if type(raw) == "table" then
        item.statsKnown = true
        for stat,token in pairs(G.StatTokens) do
            local value=raw[token]
            if issecretvalue and issecretvalue(value) then item.statsKnown=false
            elseif type(value) == "number" then
                if value~=value or value==math.huge or value==-math.huge then item.statsKnown=false
                else item.stats[stat] = value end
            elseif value~=nil then item.statsKnown=false end
        end
    elseif offline and offline.stats then
        item.stats, item.statsKnown = offline.stats, true
    end
    if C_PlayerInfo and C_PlayerInfo.CanUseItem and item.id then
        item.usable = SafeCall(C_PlayerInfo.CanUseItem,item.id)
    else
        item.usable = SafeCall(C_Item and C_Item.IsUsableItem,link)
    end
    item.unique = SafeCall(C_Item and C_Item.GetItemUniquenessByID,link)
    item.warnings = {}
    local spell = SafeCall(C_Item and C_Item.GetItemSpell,link)
    if spell then item.warnings[#item.warnings+1] = "Use/equip effect is not scored" end
    local tooltip = SafeCall(C_TooltipInfo and C_TooltipInfo.GetHyperlink,link)
    if tooltip and tooltip.lines then
        local types = Enum and Enum.TooltipDataLineType or {}
        for _,line in ipairs(tooltip.lines) do
            local kind = G.Safe(line.type)
            local text = G.Safe(line.leftText)
            if kind and (kind == types.ItemSpellTriggerOnUse or kind == types.ItemSpellTriggerOnProc
                or kind == types.ItemSpellTriggerOnEquip) then
                item.warnings[#item.warnings+1] = "Special effect is not scored"
            end
            if type(text) == "string" and text:find("%(%d+/%d+%)") then
                item.warnings[#item.warnings+1] = "Set interaction needs manual comparison"
            end
        end
        item.tooltipKnown = true
    end
    if offline then
        item.allowedClasses = offline.allowedClasses
        item.restrictionsVerified = offline.restrictionsVerified
        if offline.effects or offline.setID then item.warnings[#item.warnings+1] = "Offline effects/set bonus not scored" end
    end
    -- Do not cache an offline fallback over a pending real item response.
    if raw and tooltip then D.cache[key] = item end
    return item
end
local function Index(entry, item)
    if entry.indexed or not item or not item.loc then return end
    D.byLoc[item.loc] = D.byLoc[item.loc] or {}
    D.byLoc[item.loc][entry.key] = entry
    entry.indexed = true
end
function D.Add(record)
    local key = G.ItemKey(record.link)
    if not key then return end
    local entry = D.byLink[key]
    if not entry then
        entry = {key=key, link=record.link, sources={}}
        D.byLink[key] = entry
    end
    if record.metadata and record.metadata.foreverVerified == true then
        local previous=entry.metadata
        if previous then
            local conflict=previous.loc~=record.metadata.loc or previous.required~=record.metadata.required
            for stat,value in pairs(previous.stats or {}) do
                if (record.metadata.stats or {})[stat]~=value then conflict=true end
            end
            for stat,value in pairs(record.metadata.stats or {}) do
                if (previous.stats or {})[stat]~=value then conflict=true end
            end
            if conflict then entry.conflict=true end
        end
        entry.metadata = record.metadata
    end
    local sourceKey = table.concat({record.kind or "Unknown",record.source or "Unknown",record.url or "",record.realm or "",record.faction or ""},"|")
    entry.sources[sourceKey] = record
    D.cache[key] = nil
    local item = entry.metadata
    if not item and C_Item and C_Item.GetItemInfoInstant then
        local ok,_,_,_,loc = pcall(C_Item.GetItemInfoInstant,record.link)
        if ok and type(G.Safe(loc)) == "string" and loc ~= "" then item={loc=loc} end
    end
    if not item then item=D.Item(record.link) end
    if item then Index(entry,item) else D.pending[key] = entry end
    D.revision = D.revision + 1
end
function D.Initialize()
    if D.initialized then return end
    D.initialized = true
    -- Preserve legacy SavedVariables; build the search index once, not on redraw.
    for _,record in pairs(G.DB().sources) do D.Add(record) end
    for _,record in pairs(G.catalogue) do D.Add(record) end
end
function D.ResolvePending()
    for key,entry in pairs(D.pending) do
        local item = D.Item(entry.link)
        if item then Index(entry,item); D.pending[key]=nil end
    end
end
local oldRecord = G.Record
function G.Record(record)
    oldRecord(record)
    if D.initialized then D.Add(record) end
end
local oldImport = G.ImportWowhead
function G.ImportWowhead(records)
    local count = oldImport(records)
    if D.initialized then
        for _,record in pairs(G.catalogue) do D.Add(record) end
    end
    if G.QueueRefresh then G.QueueRefresh() end
    return count
end
-- Only generated, independently verified Forever exports belong here.
function G.RegisterDatabase(bundle)
    if type(bundle) ~= "table" or bundle.game ~= "World of Warcraft: Forever"
        or bundle.schema ~= 1 or not bundle.build or not bundle.license or not bundle.url then
        return false,"Invalid database provenance"
    end
    for _,record in ipairs(bundle.items or {}) do
        if record.foreverVerified ~= true or record.estimated or type(record.sources) ~= "table" then
            return false,"Unverified item in database"
        end
    end
    for _,item in ipairs(bundle.items or {}) do
        for _,source in ipairs(item.sources) do
            if source.foreverVerified == true and source.url then
                local record = {}
                for key,value in pairs(source) do record[key] = value end
                record.link,record.metadata = "item:" .. item.id,item
                record.provider,record.dataBuild,record.license = bundle.name,bundle.build,bundle.license
                D.Add(record)
            end
        end
    end
    D.database = {name=bundle.name,url=bundle.url,build=bundle.build}
    return true
end
