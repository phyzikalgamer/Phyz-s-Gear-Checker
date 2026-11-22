-- Independent catalogue discovery from the installed client's item index.
-- No third-party item list or acquisition claims are embedded here.
local _, G = ...
local L = {limit=400000,active=false,pending={},elapsed=0,refreshElapsed=0}
G.Learner=L
local function Now() return GetTime and GetTime() or time() end
local function State()
    local db=G.DB()
    local version,build=GetBuildInfo()
    local fingerprint=tostring(version)..":"..tostring(build)
    if not db.learning or db.learning.build~=fingerprint then
        db.learning={build=fingerprint,cursor=1,queue={},failed={},learned=0,candidates=0}
        -- Recheck old observations on a new build; never replace with Classic stats.
        for key in pairs(db.items or {}) do
            local id=tonumber(key:match("item:(%d+)"))
            if id then db.learning.queue[id]=true end
        end
    end
    return db.learning
end
local function Count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
function L.Status()
    local s=State()
    if not C_Item or not C_Item.DoesItemExistByID or not C_Item.GetItemInfoInstant
        or not C_Item.RequestLoadItemDataByID then return "Item learning unavailable on this client" end
    local state=s.paused and "Paused" or not L.active and "Paused — open Gear Review"
        or InCombatLockdown and InCombatLockdown() and "Paused in combat"
        or s.cursor>L.limit and not next(s.queue) and "Scan complete" or "Learning"
    return ("%s · %d learned · %d queued · index %.0f%%"):format(state,s.learned,Count(s.queue),math.min(100,(s.cursor-1)/L.limit*100))
end
function L.SetActive(active) L.active=active end
function L.IsScanning()
    local s=State()
    return L.active and not s.paused and not (InCombatLockdown and InCombatLockdown())
        and C_Item and C_Item.DoesItemExistByID~=nil and C_Item.GetItemInfoInstant~=nil
        and C_Item.RequestLoadItemDataByID~=nil and (s.cursor<=L.limit or next(s.queue)~=nil)
end
function L.TogglePause()
    local s=State(); s.paused=not s.paused
end
local function Discover(s)
    local checked=0
    local queued=Count(s.queue)
    while checked<500 and queued<200 and s.cursor<=L.limit do
        local id=s.cursor
        s.cursor=id+1; checked=checked+1
        if C_Item.DoesItemExistByID(id) then
            local _,_,_,loc,_,classID=C_Item.GetItemInfoInstant(id)
            if (classID==2 or classID==4) and type(loc)=="string" and loc~=""
                and loc~="INVTYPE_BODY" and loc~="INVTYPE_TABARD" then
                s.candidates=s.candidates+1
                local key="item:"..id
                local old=G.DB().items and G.DB().items[key]
                if not old or old.build~=(select(1,GetBuildInfo()).."."..tostring(select(2,GetBuildInfo()))) then
                    s.queue[id]=true; queued=queued+1
                end
            end
        end
    end
end
local function Finish(s,id,success)
    local key="item:"..id
    if success and G.Data.Observe(key,"Client catalogue") then
        s.learned=s.learned+1
        s.failed[id]=nil
        if G.InvalidateAdvisor then G.InvalidateAdvisor("CATALOGUE_UPDATED") end
    else
        s.failed[id]=time()
        G.Data.observedPending[key]=nil
    end
    s.queue[id]=nil
    L.pending[id]=nil
end
function L.Tick()
    local s=State()
    if not L.active or s.paused or InCombatLockdown and InCombatLockdown() then return end
    if not C_Item or not C_Item.DoesItemExistByID or not C_Item.GetItemInfoInstant
        or not C_Item.RequestLoadItemDataByID then return end
    G.Data.Initialize()
    -- A failed load can never hold the queue open forever.
    for id,request in pairs(L.pending) do
        if C_Item.GetItemInfo("item:"..id) then Finish(s,id,true)
        elseif Now()-request.started>=10 then Finish(s,id,false) end
    end
    Discover(s)
    local issued=0
    for id in pairs(s.queue) do
        if issued>=2 or Count(L.pending)>=20 then break end
        if not L.pending[id] then
            issued=issued+1
            if C_Item.GetItemInfo("item:"..id) then Finish(s,id,true)
            else
                L.pending[id]={started=Now()}
                -- Share the throttle with equipment/tooltip requests.
                G.requestedItems=G.requestedItems or {}
                G.requestedItems[id]=time()
                C_Item.RequestLoadItemDataByID(id)
            end
        end
    end
end
local frame=CreateFrame("Frame")
frame:SetScript("OnUpdate",function(_,elapsed)
    if not L.active then return end
    L.elapsed=L.elapsed+elapsed; L.refreshElapsed=L.refreshElapsed+elapsed
    if L.elapsed>=0.2 then L.elapsed=0; L.Tick() end
    if L.refreshElapsed>=2 then
        L.refreshElapsed=0
        if G.QueueRefresh then G.QueueRefresh() end
    end
end)
frame:SetScript("OnEvent",function(_,_,id,success)
    -- Only handle our own requests; ingest a bounded number on the next tick.
    if L.pending[id] and success==false then Finish(State(),id,false) end
end)
frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
local previous=G.AdvisorCommand
function G.AdvisorCommand(message)
    local action=message:match("^scan%s*(.-)%s*$")
    if action==nil then return previous and previous(message) end
    local s=State()
    if action=="pause" then s.paused=true
    elseif action=="resume" then s.paused=false
    elseif action=="retry" then
        for id in pairs(s.failed) do s.queue[id]=true end
        s.failed={}; s.paused=false
    elseif action~="" and action~="status" then
        print("PhyzGear: /pgear scan [status|pause|resume|retry]. Open Gear Review to learn items.")
        return true
    end
    print("PhyzGear: "..L.Status().." · "..Count(s.failed).." unavailable (retry supported)")
    return true
end
