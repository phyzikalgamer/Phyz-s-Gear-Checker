local _, G = ...
local function Count(tableValue) local n=0; for _ in pairs(tableValue or {}) do n=n+1 end; return n end
function G.DatabaseCoverage()
    G.Data.Initialize()
    local coverage={total=0,stats=0,verified=0,acquisition=0,bySlot={},byCategory={},byLevel={},pending=Count(G.Data.pending),
        offlineLoaded=G.Data.database~=nil}
    for _,entry in pairs(G.Data.byLink) do
        coverage.total=coverage.total+1
        local item=G.Data.cache[entry.key] or entry.metadata
        local loc=entry.indexedLoc or "Unknown"
        coverage.bySlot[loc]=(coverage.bySlot[loc] or 0)+1
        if item then
            if item.statsKnown or type(item.stats)=="table" then coverage.stats=coverage.stats+1 end
            if item.verified or item.foreverVerified then coverage.verified=coverage.verified+1 end
            local required=item.required
            local band=type(required)=="number" and (required==0 and "No requirement" or
                (math.floor((required-1)/10)*10+1) .. "-" .. (math.floor((required-1)/10)*10+10)) or "Unknown"
            coverage.byLevel[band]=(coverage.byLevel[band] or 0)+1
        else coverage.byLevel.Unknown=(coverage.byLevel.Unknown or 0)+1 end
        local hasSource=false
        for _,source in pairs(entry.sources) do
            if (source.foreverVerified==true or source.clientVerified==true or source.seen and source.realm)
                and (source.kind=="Vendor" or source.kind=="Auction" or source.kind=="Crafted"
                    or source.kind=="Quest" or source.kind=="Dungeon" or source.kind=="Raid") then
                hasSource=true
                coverage.byCategory[source.kind]=(coverage.byCategory[source.kind] or 0)+1
            end
        end
        if hasSource then coverage.acquisition=coverage.acquisition+1 end
    end
    return coverage
end
local function FormatCounts(counts)
    local keys,parts={},{}
    for key in pairs(counts) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do parts[#parts+1]=key.."="..counts[key] end
    return #parts>0 and table.concat(parts,", ") or "none"
end
local function PrintReport(slot)
    local options=G.Options or {}
    local result=G.Advisor.Find(slot,options.filter,options.mode,options.future)
    local d=result.diagnostics
    local gear=result.equipment[slot]
    local id=gear and gear.link and gear.link:match("item:(%d+)") or "empty"
    print(("PhyzGear slot=%s class=%s level=%s equipped=%s model=%s"):format(slot,result.context.class,result.context.level,id,result.build))
    print("Weights: "..FormatCounts(result.profile.weights or {}))
    print(("Database=%d slot candidates=%d other slots=%d result=%s"):format(d.totalDatabase,d.slotCandidates,d.slotMismatch or 0,result.code))
    print(("Rejected: level=%d class/usability=%d restrictions=%d data=%d unverified=%d unsupported=%d"):format(d.level,d.class,d.restrictions,d.unavailableData,d.unverified,d.unsupported))
    print(("Not upgrades=%d acquisition filter=%d unknown sources=%d final=%d"):format(d.notUpgrade,d.acquisitionFilter,d.sourceUnknown,d.final))
end
local previous=G.AdvisorCommand
function G.AdvisorCommand(message)
    local action=message:match("^debug%s*(.-)%s*$")
    if action==nil then return previous(message) end
    if action=="on" then G.debugEnabled=true; print("PhyzGear diagnostics enabled. /pgear debug report [slot] or /pgear debug coverage")
    elseif action=="off" then G.debugEnabled=false; print("PhyzGear diagnostics disabled.")
    elseif not G.debugEnabled then print("PhyzGear diagnostics are off. Use /pgear debug on first.")
    elseif action=="coverage" then
        local c=G.DatabaseCoverage()
        print(("PhyzGear records=%d stats=%d item-verified=%d acquisition=%d pending=%d offline=%s"):format(c.total,c.stats,c.verified,c.acquisition,c.pending,tostring(c.offlineLoaded)))
        print("Slots: "..FormatCounts(c.bySlot))
        print("Acquisition rows: "..FormatCounts(c.byCategory))
        print("Required levels: "..FormatCounts(c.byLevel))
    else
        local slot=tonumber(action:match("^report%s+(%d+)$")) or (G.Options and G.Options.slot) or 5
        if action=="report" or action:match("^report%s+%d+$") then PrintReport(slot)
        else print("PhyzGear: /pgear debug on|off|report [slot]|coverage") end
    end
    return true
end
