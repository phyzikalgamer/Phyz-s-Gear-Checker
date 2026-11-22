local _, G = ...
local window, detail, cards, selected
local WINDOW_WIDTH, CARD_WIDTH = 1050, 272
local RIGHT_X = WINDOW_WIDTH - 16 - CARD_WIDTH
local CENTER_X = 16 + CARD_WIDTH + 4
local CENTER_WIDTH = RIGHT_X - CENTER_X - 4
local function RaceBackground(parent)
    local scenery = CreateFrame("Frame",nil,parent)
    scenery:SetFrameLevel(parent:GetFrameLevel()+1)
    -- Keep every background layer inside the metal border, including 3D renders.
    scenery:SetPoint("TOPLEFT",10,-26)
    scenery:SetPoint("BOTTOMRIGHT",-10,10)
    scenery:SetClipsChildren(true)
    local _, race = UnitRace("player")
    local themes = {Human="Human",Orc="Orc",Dwarf="Dwarf",NightElf="NightElf",
        Scourge="Scourge",Tauren="Tauren",Gnome="Gnome",Troll="Troll",
        BloodElf="BloodElf",Draenei="Draenei"}
    local theme = themes[race] or (UnitFactionGroup("player") == "Horde" and "Orc" or "Human")
    local path = "Interface\\DressUpFrame\\DressUpBackground-" .. theme
    -- Blizzard's racial dressing-room artwork is split into four texture tiles.
    local tiles = {{0,0,0.8,2/3,1,1},{0.8,0,0.2,2/3,0.25,1},
        {0,2/3,0.8,1/3,1,0.5},{0.8,2/3,0.2,1/3,0.25,0.5}}
    local textures = {}
    for index,tile in ipairs(tiles) do
        local texture = scenery:CreateTexture(nil,"BACKGROUND")
        texture:SetTexture(path .. index)
        texture:SetTexCoord(0,tile[5],0,tile[6])
        textures[index] = texture
    end
    scenery:SetScript("OnSizeChanged",function(self,width,height)
        for index,tile in ipairs(tiles) do
            local texture = textures[index]
            texture:ClearAllPoints()
            texture:SetPoint("TOPLEFT",self,"TOPLEFT",width*tile[1],-height*tile[2])
            texture:SetSize(width*tile[3],height*tile[4])
        end
    end)
    -- Apply immediately as the initial layout may already have resolved.
    scenery:GetScript("OnSizeChanged")(scenery,scenery:GetWidth(),scenery:GetHeight())
    local models = {Human="Human",Orc="Orc",Dwarf="Dwarf",Gnome="Dwarf",
        NightElf="NightElf",Scourge="Scourge",Tauren="Tauren",Troll="Orc",
        BloodElf="BloodElf",Draenei="Draenei"}
    local modelRace = models[race]
    if modelRace then
        local scene = CreateFrame("Model",nil,scenery)
        scene:SetAllPoints(scenery)
        scene:SetFrameLevel(scenery:GetFrameLevel()+1)
        scene:EnableMouse(false)
        scene:Hide()
        local loaded = false
        -- SetModel can succeed before the asset has finished loading. Only replace
        -- the fallback after the engine confirms the scene is ready.
        scene:SetScript("OnModelLoaded",function(self)
            loaded = true
            self:SetCamera(0)
            self:SetSequence(0)
            self:Show()
        end)
        local path = "Interface\\Glues\\Models\\UI_" .. modelRace .. "\\UI_" .. modelRace .. ".m2"
        local ok = pcall(scene.SetModel,scene,path)
        if not ok and not loaded then scene:Hide() end
        scenery.creationScene = scene
    end
    -- Darken the summary strip without covering the frame's title or edges.
    local strip = CreateFrame("Frame",nil,scenery)
    strip:SetFrameLevel(parent:GetFrameLevel()+3)
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("TOPRIGHT")
    strip:SetHeight(32)
    local shade = strip:CreateTexture(nil,"BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0,0,0,0.8)
    return scenery
end
local function Text(parent, font, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    return text
end
local function Panel(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=16,
        insets={left=4,right=4,top=4,bottom=4}})
    return frame
end
local function Money(value)
    return value and GetMoneyString(value) or "Price not recorded"
end
local function Details(slot)
    selected = slot
    G.Options.Open(slot)
end
local function Card(parent, slot, x, y, width)
    local card = CreateFrame("Button", nil, parent)
    card:SetFrameLevel(parent:GetFrameLevel()+5)
    card:SetPoint("TOPLEFT", x, y)
    card:SetSize(width, 70)
    local bg = Panel(card)
    bg:SetFrameLevel(card:GetFrameLevel())
    bg:SetAllPoints()
    card.bg = bg
    card:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(38,38)
    card.icon:SetPoint("TOPLEFT", 8,-8)
    card.name = Text(card,"GameFontNormalSmall",52,-8,width-62)
    card.name:SetHeight(14)
    card.stats = Text(card,"GameFontHighlightSmall",52,-25,width-62)
    card.stats:SetHeight(26)
    card.status = Text(card,"GameFontDisableSmall",8,-54,width-16)
    card:SetScript("OnClick",function() Details(slot[1]); G.Refresh() end)
    card:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player",slot[1])
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave",function() GameTooltip:Hide() end)
    cards[slot[1]] = card
end
local function Build()
    window = CreateFrame("Frame","PhyzGearWindow",UIParent,"BasicFrameTemplateWithInset")
    window:SetSize(WINDOW_WIDTH,760)
    window:SetPoint("CENTER")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart",window.StartMoving)
    window:SetScript("OnDragStop",window.StopMovingOrSizing)
    window:SetFrameStrata("DIALOG")
    window.TitleText:SetText("Phyz's Gear Review")
    table.insert(UISpecialFrames,"PhyzGearWindow")
    local scale = math.min(1, UIParent:GetWidth()/(WINDOW_WIDTH+20), UIParent:GetHeight()/780)
    window:SetScale(scale)
    window.scenery = RaceBackground(window)
    local summaryFrame = CreateFrame("Frame",nil,window)
    summaryFrame:SetAllPoints(window)
    summaryFrame:SetFrameLevel(window:GetFrameLevel()+5)
    window.summary = Text(summaryFrame,"GameFontHighlight",18,-36,WINDOW_WIDTH-36)
    cards = {}
    for i,slot in ipairs(G.slots) do
        if i <= 8 then Card(window,slot,16,-66-(i-1)*73,CARD_WIDTH)
        elseif i <= 16 then Card(window,slot,RIGHT_X,-66-(i-9)*73,CARD_WIDTH)
        else Card(window,slot,(WINDOW_WIDTH-CARD_WIDTH)/2,-66-(i-17)*73,CARD_WIDTH) end
    end
    local model = CreateFrame("PlayerModel",nil,window)
    model:SetFrameLevel(window:GetFrameLevel()+4)
    model:SetPoint("TOPLEFT",CENTER_X,-296)
    model:SetSize(CENTER_WIDTH,410)
    model:SetUnit("player")
    model:SetPortraitZoom(0)
    model:SetFacing(0.25)
    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function(self) self.dragX = GetCursorPosition() end)
    model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
    model:SetScript("OnUpdate", function(self)
        if self.dragX then
            local x = GetCursorPosition()
            self:SetFacing(self:GetFacing()+(x-self.dragX)/150)
            self.dragX = x
        end
    end)
    window.model = model
    local hint = Text(summaryFrame,"GameFontNormalSmall",CENTER_X,-718,CENTER_WIDTH)
    hint:SetJustifyH("CENTER")
    hint:SetTextColor(1,0.82,0)
    hint:SetText("Drag to rotate · Select a slot for options")
    detail = CreateFrame("Frame",nil,window,"BasicFrameTemplateWithInset")
    detail:EnableMouse(true)
    detail:SetSize(440,680)
    detail:SetPoint("TOPRIGHT",window,"TOPRIGHT",-10,-56)
    detail:SetFrameLevel(window:GetFrameLevel()+20)
    detail.title = detail.TitleText
    detail.scroll = CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
    detail.scroll:EnableMouse(true)
    detail.scroll:SetPoint("TOPLEFT",14,-34)
    detail.scroll:SetPoint("BOTTOMRIGHT",-32,78)
    detail.content = CreateFrame("Frame",nil,detail.scroll)
    detail.content:SetSize(388,480)
    detail.content:EnableMouse(true)
    detail.scroll:SetScrollChild(detail.content)
    detail.body = Text(detail.content,"GameFontHighlight",0,0,380)
    detail.body:SetSpacing(4)
    detail.sourceLabel = Text(detail,"GameFontDisableSmall",14,0,408)
    detail.sourceLabel:ClearAllPoints()
    detail.sourceLabel:SetPoint("BOTTOMLEFT",14,66)
    local copy = CreateFrame("EditBox",nil,detail,"InputBoxTemplate")
    copy:SetSize(404,24)
    copy:SetPoint("BOTTOMLEFT",18,12)
    copy:SetAutoFocus(false)
    copy:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    copy:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    local function SourceButton(label,x,width,getURL)
        local button = CreateFrame("Button",nil,detail,"UIPanelButtonTemplate")
        button:SetSize(width,22)
        button:SetPoint("BOTTOMLEFT",x,42)
        button:SetText(label)
        button:SetScript("OnClick",function()
            copy:SetText(getURL())
            copy:SetFocus()
            copy:HighlightText()
        end)
    end
    SourceButton("Item source",14,132,function() return detail.sourceURL end)
    SourceButton("Guide source",152,132,function()
        local guide=G.Presets.Selected()
        return guide and guide.url or G.Wowhead.url
    end)
    SourceButton("Database",290,132,function() return G.Wowhead.url end)
    G.Options.Init(detail)
    detail:Hide()
    detail:HookScript("OnHide",function() selected=nil; G.Refresh() end)
    window:SetScript("OnShow",function() model:SetUnit("player"); G.Refresh() end)
    window:Hide()
end
function G.Refresh()
    if not window or not window:IsShown() then return end
    local review,upgrades,unrated = 0,0,0
    for id,gear in pairs(G.Equipment()) do
        local card = cards[id]
        local item = gear.item
        gear.state,gear.reason = G.Advisor.Assess(gear)
        card.icon:SetTexture(item and item.icon or GetInventoryItemTexture("player",id) or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        card.name:SetText(item and item.name or (gear.link and "Loading item…" or gear.label))
        local r,g,b = 1,0.82,0
        if item and item.quality then r,g,b = C_Item.GetItemQualityColor(item.quality) end
        card.name:SetTextColor(r,g,b)
        card.stats:SetText(item and G.Stats(id) or "")
        local flag = gear.state == "Review" or gear.state == "Potential Upgrade"
        if gear.state == "Review" then review=review+1 end
        if gear.state == "Potential Upgrade" then upgrades=upgrades+1 end
        if gear.state == "Unrated" or gear.state == "Loading" then unrated=unrated+1 end
        card.status:SetText(gear.state .. (item and (" · iLvl " .. (item.level or "?")) or "") .. " · Options >")
        card.status:SetTextColor(flag and 1 or 0.65,flag and 0.55 or 0.65,flag and 0.15 or 0.65)
        card.bg:SetBackdropBorderColor(selected == id and 1 or 0.45,selected == id and 0.82 or 0.45,0.3)
    end
    window.summary:SetText(("%s · Level %s     |     %d potential upgrades · %d age/empty reviews · %d unrated"):format(
        UnitName("player") or "Player",G.Safe(UnitLevel("player")) or "?",upgrades,review,unrated))
    if detail and detail:IsShown() then G.Options.Render(false) end
end
local refreshQueued=false
function G.QueueRefresh()
    if refreshQueued then return end
    refreshQueued=true
    C_Timer.After(0.1,function() refreshQueued=false; G.Refresh() end)
end
function G.Toggle()
    if not window then Build() end
    window:SetShown(not window:IsShown())
end

function G.CreateMinimap()
    if G.minimapButton or not Minimap then return end
    local button = CreateFrame("Button","PhyzGearMinimapButton",Minimap)
    button:SetSize(32,32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel()+8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil,"BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Chest_Plate04")
    icon:SetSize(20,20)
    icon:SetPoint("CENTER",0,0)
    local border = button:CreateTexture(nil,"OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54,54)
    border:SetPoint("TOPLEFT",0,0)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local function Position(angle)
        local radians = math.rad(angle)
        button:ClearAllPoints()
        button:SetPoint("CENTER",Minimap,"CENTER",math.cos(radians)*(Minimap:GetWidth()/2+6),
            math.sin(radians)*(Minimap:GetHeight()/2+6))
    end
    Position(G.DB().minimapAngle or 220)
    button:SetScript("OnClick",function() if not button.wasDragged then G.Toggle() end end)
    button:SetScript("OnDragStart",function(self)
        self.wasDragged = true
        self:SetScript("OnUpdate",function()
            local x,y = GetCursorPosition()
            local cx,cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local angle = math.deg(math.atan2(y/scale-cy,x/scale-cx))
            G.DB().minimapAngle = angle
            Position(angle)
        end)
    end)
    button:SetScript("OnDragStop",function(self)
        self:SetScript("OnUpdate",nil)
        C_Timer.After(0,function() self.wasDragged=false end)
    end)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Phyz's Gear Review")
        GameTooltip:AddLine("Click to open or close",1,1,1)
        GameTooltip:AddLine("Drag to move around the minimap",1,1,1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    G.minimapButton = button
end
