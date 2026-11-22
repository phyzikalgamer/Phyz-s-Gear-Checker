local _, G = ...
local A = {cache={}}
G.Advisor = A
G.SourceCategories = {"All","Vendors","Auction House","Crafting","Quests","Dungeons","Raids"}
local category = {Vendor="Vendors",Auction="Auction House",Crafted="Crafting",Quest="Quests",Dungeon="Dungeons",Raid="Raids"}
local locations = {
    [1]={"INVTYPE_HEAD"},[2]={"INVTYPE_NECK"},[3]={"INVTYPE_SHOULDER"},[15]={"INVTYPE_CLOAK"},
    [5]={"INVTYPE_CHEST","INVTYPE_ROBE"},[9]={"INVTYPE_WRIST"},[10]={"INVTYPE_HAND"},
    [6]={"INVTYPE_WAIST"},[7]={"INVTYPE_LEGS"},[8]={"INVTYPE_FEET"},
    [11]={"INVTYPE_FINGER"},[12]={"INVTYPE_FINGER"},[13]={"INVTYPE_TRINKET"},[14]={"INVTYPE_TRINKET"},
    [16]={"INVTYPE_WEAPON","INVTYPE_WEAPONMAINHAND","INVTYPE_2HWEAPON"},
    [17]={"INVTYPE_WEAPON","INVTYPE_WEAPONOFFHAND","INVTYPE_SHIELD","INVTYPE_HOLDABLE"},
    [18]={"INVTYPE_RANGED","INVTYPE_RANGEDRIGHT","INVTYPE_THROWN"},
}
function G.InvalidateAdvisor(event)
    A.cache = {}
    A.equipment = nil
    if event == "GET_ITEM_INFO_RECEIVED" or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED" or event == "SKILL_LINES_CHANGED" or event == "PLAYER_LEVEL_UP" then
        G.Data.cache = {}
    end
    if event == "GET_ITEM_INFO_RECEIVED" then G.Data.ResolvePending() end
    if event == "AUCTION_HOUSE_CLOSED" then G.currentAuctionObservations = {} end
    if event == "BAG_UPDATE_DELAYED" then G.sessionCrafts = {} end
end
local function Context()
    local _,class = UnitClass("player")
    return {class=class,level=G.Safe(UnitLevel("player")) or 1,faction=UnitFactionGroup("player"),realm=GetRealmName()}
end
local function Equipment()
    if A.equipment then return A.equipment end
    local equipment = G.Equipment()
    for _,gear in pairs(equipment) do if gear.link then gear.item = G.Data.Item(gear.link) end end
    A.equipment = equipment
    return equipment
end
local function Restriction(item,slot,equipment,context,future)
    if type(item.required) ~= "number" then return "Required level unknown" end
    if item.required > context.level and not future then return "Future level" end
    if item.allowedClasses and not item.allowedClasses[context.class] then return "Class restriction" end
    if slot==17 and (item.loc=="INVTYPE_WEAPON" or item.loc=="INVTYPE_WEAPONOFFHAND") then
        if G.SafeCall(CanDualWield) ~= true then return "Dual-wield capability not confirmed" end
    end
    if item.required <= context.level then
        if item.usable ~= true then return "Client has not confirmed item usability" end
    elseif item.restrictionsVerified ~= true or not item.allowedClasses then
        return "Future proficiency requirements unknown"
    end
    local candidateCategory
    if C_Item and C_Item.GetItemUniqueness then candidateCategory = G.SafeCall(C_Item.GetItemUniqueness,item.link) end
    for id,gear in pairs(equipment) do
        local removed = id == slot or (slot == 16 and item.loc == "INVTYPE_2HWEAPON" and id == 17)
        if not removed and gear.item then
            if item.unique and gear.item.id == item.id then return "Unique-equipped conflict" end
            if candidateCategory and candidateCategory > 0 and C_Item and C_Item.GetItemUniqueness then
                local otherCategory = G.SafeCall(C_Item.GetItemUniqueness,gear.link)
                if otherCategory == candidateCategory then return "Unique category needs manual comparison" end
            end
        end
    end
    if item.unique == nil and not item.restrictionsVerified then return "Unique restrictions unknown" end
    if not item.tooltipKnown and not item.restrictionsVerified then return "Tooltip requirements still loading" end
    return nil
end
local function SourceAllowed(source,context,future)
    if not category[source.kind] then return false end
    if source.realm and source.realm ~= context.realm then return false end
    if source.faction and source.faction ~= context.faction then return false end
    if source.kind == "Quest" and source.questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        if G.SafeCall(C_QuestLog.IsQuestFlaggedCompleted,source.questID) and not source.repeatable then return false end
    end
    if source.minLevel and source.minLevel>context.level and not future then return false end
    -- Old observed records are evidence of an actual encounter, never current stock.
    return source.foreverVerified == true or source.clientVerified == true or (source.seen ~= nil and source.realm ~= nil)
end
local function AuctionHint(item)
    if item.binding ~= 2 then return nil end
    local source={kind="Auction",source="Potential Auction House purchase (Bind on Equip)",
        clientVerified=true,potential=true,url=G.ResearchURL(0,item.link)}
    local api=Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetAuctionPriceByItemLink then
        local price=G.SafeCall(api.GetAuctionPriceByItemLink,"PhyzGear",item.link)
        if type(price)=="number" and price>0 then
            source.price,source.unitPrice,source.potential=price,true,false
            source.source="Auctionator cached price (not a live listing)"
            if api.GetAuctionAgeByItemLink then
                source.ageDays=G.SafeCall(api.GetAuctionAgeByItemLink,"PhyzGear",item.link)
            end
        end
    end
    return source
end
local function Accessibility(source)
    if source.owned then return 0,"Already in your bags" end
    if source.kind == "Crafted" and source.canCraft == true and G.sessionCrafts
        and G.sessionCrafts[source.recipeID] then return 1,"Recipe ready when observed this session; recheck materials" end
    if source.kind == "Vendor" and G.sessionVendors and G.sessionVendors[source.source .. "|" .. (source.location or "")] and source.price
        and source.price <= (G.Safe(GetMoney()) or 0) and not source.extendedCost
        and not source.requirements then return 1,"Visited this session; recorded gold cost affordable" end
    if source.kind == "Auction" and G.currentAuctionObservations
        and G.currentAuctionObservations[source.source] then
        return 2,"Observed in this AH session; listing may have changed"
    end
    if source.availabilityVerified == true and source.available == true then return 3,"Source availability confirmed by provider" end
    return 9,"Accessibility unknown; check source requirements"
end
function A.Find(slot,filter,mode,future)
    filter,mode=filter or "All",mode or "Best Upgrade"
    G.Data.Initialize()
    local key=table.concat({slot,filter,mode,future and "future" or "now",G.Data.revision},"|")
    if A.cache[key] then return A.cache[key] end
    local profile,build=G.Profile(slot)
    local equipment,context=Equipment(),Context()
    local stats={totalDatabase=G.Data.entryCount,slotCandidates=0,level=0,class=0,restrictions=0,
        unavailableData=0,unverified=0,unsupported=0,notUpgrade=0,acquisitionFilter=0,sourceUnknown=0,final=0}
    local result={rows={},skipped={},context=context,equipment=equipment,build=build,profile=profile,
        considered=0,diagnostics=stats,code=""}
    A.cache[key]=result
    local function Empty(code,text) result.code=code; result.reason=text; return result end
    if not equipment[slot] then return Empty("INVALID_SLOT","Select a valid equipment slot.") end
    if slot==4 or slot==19 then return Empty("OPTIONAL","Cosmetic slot; no combat upgrade assessment.") end
    local selected={}
    for _,loc in ipairs(locations[slot] or {}) do
        for entryKey,entry in pairs(G.Data.byLoc[loc] or {}) do selected[entryKey]=entry; stats.slotCandidates=stats.slotCandidates+1 end
    end
    stats.slotMismatch=math.max(0,G.Data.indexedCount-stats.slotCandidates)
    if not next(profile.weights or {}) then return Empty("NO_SCORING","Choose a spec/preset or configure Custom weights to compare items.") end
    if G.Data.entryCount==0 then
        return Empty(G.Data.database and "DATABASE_EMPTY" or "DATABASE_NOT_LOADED",
            G.Data.database and "The offline catalogue is loaded but contains no equipment records."
                or "No equipment records loaded. Open bags or visit vendors to collect client-verified items; no offline catalogue is bundled.")
    end
    if stats.slotCandidates==0 then return Empty("NO_SLOT_RECORDS","No equipment records are indexed for this slot yet.") end
    local current=equipment[slot]
    if current.link and (not current.item or not current.item.statsKnown) then
        return Empty("CURRENT_DATA_UNAVAILABLE","Equipped item statistics are unavailable or still loading.")
    end
    local function Skip(reason,group)
        result.skipped[reason]=(result.skipped[reason] or 0)+1
        stats[group or "restrictions"]=stats[group or "restrictions"]+1
    end
    for entryKey,entry in pairs(selected) do
        if G.ItemKey(current.link)~=entryKey then
            result.considered=result.considered+1
            local item=G.Data.Item(entry.link)
            local why
            if entry.conflict then why="Conflicting offline item records"; Skip(why,"unverified")
            elseif not item or not item.statsKnown then why="Candidate stats unavailable or still loading"; Skip(why,"unavailableData")
            elseif not item.verified then why="Item statistics are unverified"; Skip(why,"unverified")
            else
                why=Restriction(item,slot,equipment,context,future)
                if why then
                    local group=(why=="Future level" or why=="Future proficiency requirements unknown") and "level"
                        or (why=="Class restriction" or why=="Client has not confirmed item usability" or why=="Dual-wield capability not confirmed") and "class" or "restrictions"
                    Skip(why,group)
                end
            end
            if not why then
                local comparison,reason=G.Scoring.Compare(slot,item,equipment,profile.weights)
                if not comparison then Skip(reason,"unsupported")
                elseif comparison.delta<=0 then Skip("No positive weighted stat difference","notUpgrade")
                else
                    local sources={}
                    for _,source in pairs(entry.sources) do
                        if SourceAllowed(source,context,future) and (filter=="All" or category[source.kind]==filter) then sources[#sources+1]=source end
                    end
                    if filter=="All" or filter=="Auction House" then
                        local hasAuction=false
                        for _,source in ipairs(sources) do if source.kind=="Auction" then hasAuction=true end end
                        if not hasAuction then local hint=AuctionHint(item); if hint then sources[#sources+1]=hint end end
                    end
                    if filter=="All" and (G.ownedBagLinks and G.ownedBagLinks[entryKey]) then
                        sources[#sources+1]={kind="Owned",source="Already in your bags",owned=true,clientVerified=true}
                    end
                    if #sources==0 and filter=="All" then
                        sources[1]={kind="Unknown",source="Acquisition source unknown",url=entry.metadata and entry.metadata.url,
                            provider=entry.provider or (item.clientStatsKnown and "Current WoW Forever client" or nil),
                            dataBuild=entry.metadata and entry.metadata.build,clientVerified=item.clientStatsKnown or nil}
                        stats.sourceUnknown=stats.sourceUnknown+1
                    end
                    if #sources==0 then Skip("Upgrade excluded by acquisition filter","acquisitionFilter")
                    else
                        table.sort(sources,function(a,b)
                            local ea,eb=Accessibility(a),Accessibility(b)
                            if ea~=eb then return ea<eb end
                            return (a.source or "")<(b.source or "")
                        end)
                        local ease,access=Accessibility(sources[1])
                        result.rows[#result.rows+1]={item=item,sources=sources,source=sources[1],comparison=comparison,
                            ease=ease,access=access,future=math.max(0,item.required-context.level)}
                    end
                end
            end
        end
    end
    table.sort(result.rows,function(a,b)
        if mode=="Easiest Upgrade" and a.ease~=b.ease then return a.ease<b.ease end
        if a.comparison.delta~=b.comparison.delta then return a.comparison.delta>b.comparison.delta end
        return (a.item.name or "")<(b.item.name or "")
    end)
    stats.final=#result.rows
    if #result.rows>0 then result.code=stats.sourceUnknown>0 and "UPGRADES_WITH_UNKNOWN_SOURCES" or "UPGRADES"; return result end
    if result.considered==0 then return Empty("NO_ALTERNATIVE_RECORDS","Only the equipped item is recorded for this slot. Inspect alternatives or collect bag/vendor items.") end
    if stats.acquisitionFilter>0 then return Empty("ACQUISITION_FILTERED","Stat upgrades were found, but none match this acquisition filter. Try All sources.") end
    if stats.notUpgrade>0 then return Empty("NO_BETTER_ITEMS","No better items found among the comparable records. This is not a best-in-slot claim.") end
    if stats.unavailableData+stats.unverified>0 then return Empty("ITEM_DATA_UNAVAILABLE","Candidate item data is unavailable, loading, unverified or conflicting.") end
    if stats.unsupported>0 then return Empty("UNSUPPORTED_COMPARISON","Available items require an unsupported effect or weapon-setup comparison.") end
    return Empty("NO_COMPATIBLE_ITEMS","No compatible replacement items match your level, class and equipment restrictions.")
end
function A.Assess(gear)
    if gear.state == "Optional" or gear.state == "Loading" then return gear.state,gear.reason end
    local result = A.Find(gear.id)
    if result.rows[1] then
        return "Potential Upgrade","Positive stat difference under your selected weights; inspect the comparison."
    end
    if gear.state == "Review" then return "Review",gear.reason .. " No verified improvement assessed yet." end
    return "Unrated",result.reason or "No verified better comparison; coverage is incomplete."
end
-- Compatibility for callers of the original candidates function.
function G.Candidates(equipped) return A.Find(equipped.id).rows end
