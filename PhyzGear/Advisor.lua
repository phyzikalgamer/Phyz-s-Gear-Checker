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
    filter,mode = filter or "All",mode or "Best Upgrade"
    G.Data.Initialize()
    local key = table.concat({slot,filter,mode,future and "future" or "now",G.Data.revision},"|")
    if A.cache[key] then return A.cache[key] end
    local profile,build = G.Profile(slot)
    local equipment,context = Equipment(),Context()
    local result = {rows={},skipped={},context=context,equipment=equipment,build=build,
        profile=profile,considered=0}
    A.cache[key] = result
    if slot == 4 or slot == 19 then result.reason="Cosmetic slot"; return result end
    if not next(profile.weights or {}) then result.reason="Set stat weights for your intended build to rank upgrades."; return result end
    local current = equipment[slot]
    if current.link and (not current.item or not current.item.statsKnown) then
        result.reason="Equipped item statistics are unavailable or still loading."; return result
    end
    local function Skip(reason) result.skipped[reason]=(result.skipped[reason] or 0)+1 end
    for _,loc in ipairs(locations[slot] or {}) do
        for _,entry in pairs(G.Data.byLoc[loc] or {}) do
            if G.ItemKey(current.link) ~= entry.key then
                local item = G.Data.Item(entry.link)
                local sources = {}
                for _,source in pairs(entry.sources) do
                    if SourceAllowed(source,context,future) and (filter == "All" or category[source.kind] == filter) then
                        sources[#sources+1] = source
                    end
                end
                if (filter == "All" or filter == "Auction House") and item then
                    local hasAuction=false
                    for _,source in ipairs(sources) do if source.kind=="Auction" then hasAuction=true end end
                    if not hasAuction then
                        local hint=AuctionHint(item)
                        if hint then sources[#sources+1]=hint end
                    end
                end
                if #sources > 0 then
                    result.considered = result.considered+1
                    local why
                    if entry.conflict then why="Conflicting offline item records"
                    elseif item then why=Restriction(item,slot,equipment,context,future)
                    else why="Candidate data loading" end
                    if why then Skip(why) else
                        local comparison,reason = G.Scoring.Compare(slot,item,equipment,profile.weights)
                        if not comparison then Skip(reason)
                        elseif comparison.delta <= 0 then Skip("No positive weighted stat difference")
                        else
                            table.sort(sources,function(a,b)
                                local ea,eb = Accessibility(a),Accessibility(b)
                                if ea ~= eb then return ea<eb end
                                return (a.source or "") < (b.source or "")
                            end)
                            local ease,access = Accessibility(sources[1])
                            result.rows[#result.rows+1] = {item=item,sources=sources,source=sources[1],
                                comparison=comparison,ease=ease,access=access,
                                future=math.max(0,item.required-context.level)}
                        end
                    end
                end
            end
        end
    end
    table.sort(result.rows,function(a,b)
        if mode == "Easiest Upgrade" and a.ease ~= b.ease then return a.ease<b.ease end
        if a.comparison.delta ~= b.comparison.delta then return a.comparison.delta>b.comparison.delta end
        return (a.item.name or "") < (b.item.name or "")
    end)
    if #result.rows == 0 then
        result.reason = result.considered == 0 and "No verified source records for this slot/filter. Database coverage is incomplete."
            or "No comparable improvements in the available data. This does not mean best-in-slot."
    end
    return result
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
