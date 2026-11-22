local _, G = ...
local S = {}
G.Scoring = S
function S.Score(item, weights)
    if not item or not item.statsKnown then return nil,"Item stats unavailable" end
    if not weights or not next(weights) then return nil,"Select an intended build and stat weights" end
    local score = 0
    for stat,weight in pairs(weights) do
        local value = item.stats[stat] or 0
        if type(value) ~= "number" or type(weight) ~= "number" then return nil,"Invalid stat value" end
        score = score + value*weight
    end
    return score
end
function S.Compare(slot, candidate, equipment, weights)
    local current = equipment[slot] and equipment[slot].item
    local replaced = {slot}
    if slot == 17 and equipment[16] and equipment[16].item
        and equipment[16].item.loc == "INVTYPE_2HWEAPON" then
        return nil,"Off hand needs a planned one-hand setup"
    end
    if slot == 16 then
        if candidate.loc == "INVTYPE_2HWEAPON" then
            if equipment[17] and equipment[17].link then replaced[#replaced+1]=17 end
        elseif current and current.loc == "INVTYPE_2HWEAPON" then
            return nil,"One-hand replacement needs a complete main/off-hand plan"
        end
    end
    local candidateScore,reason = S.Score(candidate,weights)
    if not candidateScore then return nil,reason end
    local currentScore,stats,cautions = 0,{},{}
    for _,id in ipairs(replaced) do
        local gear = equipment[id]
        if gear and gear.link then
            if not gear.item then return nil,"Equipped item data still loading" end
            if gear.item.warnings and #gear.item.warnings > 0 then return nil,gear.item.warnings[1] end
            for _,caution in ipairs(gear.item.cautions or {}) do cautions[#cautions+1]=caution end
            local score,why = S.Score(gear.item,weights)
            if not score then return nil,why end
            currentScore = currentScore + score
            for stat,value in pairs(gear.item.stats) do stats[stat] = (stats[stat] or 0)+value end
        end
    end
    if candidate.warnings and #candidate.warnings > 0 then return nil,candidate.warnings[1] end
    for _,caution in ipairs(candidate.cautions or {}) do cautions[#cautions+1]=caution end
    local changes = {}
    for stat,value in pairs(candidate.stats) do changes[stat] = value-(stats[stat] or 0) end
    for stat,value in pairs(stats) do
        if candidate.stats[stat] == nil then changes[stat] = -value end
    end
    return {delta=candidateScore-currentScore,currentScore=currentScore,candidateScore=candidateScore,
        changes=changes,replaced=replaced,cautions=cautions}
end
function G.CharacterKey()
    return (GetRealmName() or "") .. ":" .. (UnitName("player") or "")
end
function G.Profile()
    local db = G.DB()
    db.characters = db.characters or {}
    local key = G.CharacterKey()
    db.characters[key] = db.characters[key] or {profiles={},active="Custom build"}
    local character = db.characters[key]
    character.profiles = character.profiles or {}
    character.active = character.active or "Custom build"
    character.profiles[character.active] = character.profiles[character.active] or {weights={}}
    return character.profiles[character.active],character.active
end
function G.ParseWeights(text)
    local weights,seen = {},false
    for pair in text:gmatch("%S+") do
        local key,value = pair:match("^([%a]+)=([%d%.%-]+)$")
        value = tonumber(value)
        if not key or not G.StatTokens[key] or not value or value ~= value or math.abs(value)>10000 then
            return nil,"Use supported stat=value pairs, e.g. agility=1 stamina=0.3"
        end
        if weights[key] ~= nil then return nil,"Duplicate stat: " .. key end
        weights[key],seen = value,true
    end
    if not seen then return nil,"Enter at least one stat weight" end
    return weights
end
function G.SetWeights(text)
    local weights,errorText = G.ParseWeights(text)
    if not weights then return false,errorText end
    local profile = (G.CustomProfile or G.Profile)()
    profile.weights = weights
    profile.model = "User-defined additive stat comparison"
    if G.Presets then G.Presets.Settings().preset="Custom" end
    if G.InvalidateAdvisor then G.InvalidateAdvisor("PROFILE") end
    if G.Refresh then G.Refresh() end
    return true
end
function G.AdvisorCommand(message)
    local cmd,rest = message:match("^(%S+)%s*(.-)%s*$")
    if cmd == "weights" then
        local ok,why = G.SetWeights(rest)
        print("PhyzGear: " .. (ok and "Stat weights saved for this character/build." or why))
        return true
    elseif cmd == "build" then
        if #rest < 1 or #rest > 60 then print("PhyzGear: /pgear build <intended build name>"); return true end
        if G.Presets then G.Presets.Settings().preset="Custom" end
        local db = G.DB().characters or {}
        G.Profile()
        db = G.DB().characters
        db[G.CharacterKey()].active = rest
        G.Profile()
        if G.InvalidateAdvisor then G.InvalidateAdvisor("PROFILE") end
        if G.Refresh then G.Refresh() end
        print("PhyzGear: Intended build: " .. rest .. ". Configure weights for this build.")
        return true
    elseif cmd == "help" then
        print("PhyzGear: /pgear; /pgear build <name>; /pgear weights agility=1 stamina=0.3")
        print("Weights are your comparison preferences, not validated performance estimates.")
        return true
    end
    return false
end
