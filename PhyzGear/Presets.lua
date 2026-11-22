local _, G = ...
local P={checked="2026-11-22",version=1}
G.Presets=P
local base="https://www.wowhead.com/forever/guide/classes/"
local function Guide(class,id,name,role,focus,path,note)
    return {id=id,name=name,role=role,focus=focus,url=base..class.."/"..path,
        checked=P.checked,note=note or "Guide priorities are provisional; caps and talent effects need manual review."}
end
-- These short stat groups are guide-informed inputs, not reproduced weight tables.
P.guides={
 HUNTER={
  Guide("hunter","beast-mastery","Beast Mastery","ranged",{"agility","intellect","rangedAttackPower"},"beast-mastery/stat-priority-pve-dps","Intellect value depends on Careful Aim; preset does not assume that talent. Hit cap needs manual review."),
  Guide("hunter","marksmanship","Marksmanship","ranged",{"agility","intellect","rangedAttackPower"},"marksmanship/stat-priority-pve-dps"),
  Guide("hunter","survival","Survival","physical",{"agility","strength","attackPower","intellect"},"survival/stat-priority-pve-dps","Melee/ranged balance depends on your build; compare weapon setup manually."),
 },
 WARRIOR={
  Guide("warrior","arms","Arms","physical",{"strength","agility","attackPower"},"arms/stat-priority-pve-dps"),
  Guide("warrior","fury","Fury","physical",{"strength","agility","attackPower"},"fury/stat-priority-pve-dps"),
  Guide("warrior","protection","Protection","tank",{"strength","attackPower","agility"},"protection/stat-priority-pve-tank","Guide distinguishes balanced, defensive and offensive gearing; defense and expertise caps are not modelled."),
 },
 PALADIN={
  Guide("paladin","holy","Holy","healer",{"healing","intellect","spirit"},"holy/stat-priority-pve-healer"),
  Guide("paladin","protection","Protection","tank",{"spellPower","strength","agility"},"protection/stat-priority-pve-tank"),
  Guide("paladin","retribution","Retribution","physical",{"spellPower","intellect","strength","attackPower","agility"},"retribution/stat-priority-pve-dps","Twisting and Shockadin have different weapon-speed needs. These are not simulated."),
 },
 ROGUE={
  Guide("rogue","assassination","Assassination","physical",{"agility","strength","attackPower"},"assassination/stat-priority-pve-dps"),
  Guide("rogue","combat","Combat","physical",{"agility","strength","attackPower"},"combat/stat-priority-pve-dps"),
  Guide("rogue","subtlety","Subtlety","physical",{"agility","strength","attackPower"},"subtlety/stat-priority-pve-dps"),
 },
 PRIEST={
  Guide("priest","discipline","Discipline","healer",{"healing","intellect","spirit","spellPower"},"discipline/stat-priority-pve-healer"),
  Guide("priest","holy","Holy","healer",{"healing","intellect","mp5","spirit"},"holy/stat-priority-pve-healer"),
  Guide("priest","shadow","Shadow","caster",{"spellPower","intellect","spirit"},"shadow/stat-priority-pve-dps"),
 },
 SHAMAN={
  Guide("shaman","elemental","Elemental","caster",{"spellPower","intellect","spirit"},"elemental/stat-priority-pve-dps","Spell Pierce and school-specific damage are not currently scored by these presets."),
  Guide("shaman","enhancement","Enhancement","physical",{"strength","intellect","agility","spellPower","attackPower"},"enhancement/stat-priority-pve-dps"),
  Guide("shaman","restoration","Restoration","healer",{"healing","intellect","spirit","mp5"},"restoration/stat-priority-pve-healer"),
 },
 MAGE={
  Guide("mage","arcane","Arcane","caster",{"spellPower","intellect","spirit"},"arcane/stat-priority-pve-dps"),
  Guide("mage","fire","Fire","caster",{"spellPower","intellect","spirit"},"fire/stat-priority-pve-dps"),
  Guide("mage","frost","Frost","caster",{"spellPower","intellect","spirit"},"frost/stat-priority-pve-dps"),
 },
 WARLOCK={
  Guide("warlock","affliction","Affliction","caster",{"spellPower","intellect","spirit"},"affliction/stat-priority-pve-dps","Guide has build-dependent weights. Shadow damage and Spell Pierce are not scored here."),
  Guide("warlock","demonology","Demonology","caster",{"spellPower","intellect","spirit"},"demonology/stat-priority-pve-dps"),
  Guide("warlock","destruction","Destruction","caster",{"spellPower","intellect","spirit"},"destruction/stat-priority-pve-dps"),
 },
 DRUID={
  Guide("druid","balance","Balance","caster",{"spellPower","intellect","spirit"},"balance/stat-priority-pve-dps"),
  Guide("druid","feral-dps","Feral (Cat)","physical",{{"agility","strength"},"attackPower","intellect","spirit"},"feral/stat-priority-pve-dps","Agility and Strength share a heuristic tier; feral weapon DPS conversion is not assumed."),
  Guide("druid","feral-tank","Feral (Bear)","tank",{"agility","strength","attackPower"},"feral/stat-priority-pve-tank"),
  Guide("druid","restoration","Restoration","healer",{"healing","spirit","intellect","mp5"},"restoration/stat-priority-pve-healer"),
 },
}
G.CustomProfile=G.Profile
function P.Settings()
    G.CustomProfile()
    return G.DB().characters[G.CharacterKey()]
end
function P.List()
    local _,class=UnitClass("player")
    return P.guides[class] or {}
end
function P.Selected()
    local settings=P.Settings()
    for _,guide in ipairs(P.List()) do if guide.id==settings.guideSpec then return guide end end
end
local function Changed()
    if G.InvalidateAdvisor then G.InvalidateAdvisor("PROFILE") end
    if G.Refresh then G.Refresh() end
end
function P.ChooseSpec(id)
    for _,guide in ipairs(P.List()) do
        if guide.id==id then
            local settings=P.Settings()
            settings.guideSpec=id
            if not settings.preset or settings.preset=="Custom" then settings.preset="Recommended" end
            Changed()
            return true
        end
    end
    return false
end
function P.Choose(mode)
    if mode~="Recommended" and mode~="Attack" and mode~="Survivability" and mode~="Custom" then return false end
    if mode~="Custom" and not P.Selected() then return false end
    P.Settings().preset=mode
    Changed()
    return true
end
function P.Profile(guide,mode,slot)
    -- Authored policy coefficients. Never describe these as Wowhead stat weights.
    local tiers={1,0.6,0.35,0.2,0.1}
    local weights={}
    for index,group in ipairs(guide.focus) do
        if type(group)~="table" then group={group} end
        for _,stat in ipairs(group) do weights[stat]=tiers[index] or 0.05 end
    end
    weights.crit,weights.haste=0.1,0.08
    if guide.role=="ranged" then
        weights.attackPower=weights.rangedAttackPower
        -- Mana remains useful, but Careful Aim's offensive conversion is not assumed.
        weights.intellect=0.25
    end
    if mode=="Attack" then
        weights.stamina,weights.armor,weights.spirit,weights.mp5=nil,nil,nil,nil
        if guide.role=="healer" then
            weights={spellPower=1,intellect=0.25,crit=0.1,haste=0.08}
        end
    elseif mode=="Survivability" then
        weights={stamina=1,armor=0.02}
    else
        weights.stamina=0.35
        if guide.role=="tank" then
            for stat,value in pairs(weights) do weights[stat]=value*0.5 end
            weights.stamina,weights.armor=1,0.02
        end
    end
    -- A ranged Hunter's melee DPS must never increase this score. Feral
    -- conversions and weapon speed are unsupported, so do not score them either.
    if mode~="Survivability" and (guide.role=="ranged" and slot==18
        or guide.role=="physical" and slot==16 and not guide.id:find("feral")
        or guide.role=="tank" and slot==16 and guide.id~="feral-tank") then weights.dps=2 end
    return {weights=weights,preset=mode,guide=guide,model="Guide-informed heuristic",
        notice="Phyz estimate, not Wowhead numeric weights. Hit/expertise/defense caps, school damage and talent scaling are not scored."}
end
function G.Profile(slot)
    local custom,name=G.CustomProfile()
    local settings=P.Settings()
    local guide=P.Selected()
    if guide and settings.preset and settings.preset~="Custom" then
        return P.Profile(guide,settings.preset,slot),guide.name .. " · " .. settings.preset
    end
    return custom,name
end
