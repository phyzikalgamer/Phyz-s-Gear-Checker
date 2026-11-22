local _, G = ...
local O = {filter="All",mode="Best Upgrade",future=false,expanded=false,limit=20,rows={}}
G.Options = O
local function Text(parent,font,width)
    local text=parent:CreateFontString(nil,"OVERLAY",font)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetSpacing(3)
    return text
end
local function Button(parent,label,x,y,width,action)
    local button=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT",x,y)
    button:SetSize(width,21)
    button:SetText(label)
    button:SetScript("OnClick",action)
    return button
end
local function StatLines(stats)
    local keys,lines={},{}
    for key in pairs(stats or {}) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do
        if stats[key] ~= 0 then lines[#lines+1]=key .. ": " .. string.format("%g",stats[key]) end
    end
    return #lines>0 and table.concat(lines," · ") or "No mapped statistics"
end
local function StatName(stat)
    local names={attackPower="Attack power",rangedAttackPower="Ranged attack power",spellPower="Spell power",
        crit="Crit rating",haste="Haste rating",hit="Hit rating",defense="Defense rating",dps="Weapon DPS",
        mp5="Mana per 5 sec",blockValue="Block value"}
    return names[stat] or stat:sub(1,1):upper() .. stat:sub(2)
end
local function SourceLines(source)
    local lines={source.kind .. ": " .. source.source}
    for _,key in ipairs({"location","zone","instance","boss","profession","recipe","materials","requirements","reputation","currency","prerequisites","questGiver"}) do
        if source[key] then lines[#lines+1]=key .. ": " .. tostring(source[key]) end
    end
    if source.minLevel then lines[#lines+1]="Source minimum level: " .. source.minLevel end
    if source.skill then lines[#lines+1]="Profession skill: " .. source.skill end
    if source.kind == "Crafted" then
        lines[#lines+1]=source.canCraft == true and "Craftable when observed; recheck materials"
            or "Crafting readiness unknown; another crafter may be required"
    end
    if source.kind == "Quest" then
        lines[#lines+1]="Quest availability and reward choices must be checked."
    end
    if source.price then
        lines[#lines+1]=(source.unitPrice and "Cached unit price: " or "Recorded cost: ") .. GetMoneyString(source.price)
        if source.quantity and source.quantity>1 then lines[#lines+1]="Total for stack of " .. source.quantity end
    end
    if source.extendedCost then lines[#lines+1]="Additional items/currency required" end
    if source.chance and source.chanceVerified then lines[#lines+1]="Verified drop rate: " .. source.chance .. "%" end
    if source.seen then
        local age=math.max(0,time()-source.seen)
        lines[#lines+1]="Observed: " .. date("%d %b %Y %H:%M",source.seen) .. " (" .. math.floor(age/60) .. " minutes ago)"
    end
    if source.ageDays then lines[#lines+1]="Price age: " .. source.ageDays .. " days (Auctionator resolution)" end
    if source.kind == "Auction" then
        lines[#lines+1]=source.potential and "Potentially tradable; no listing observed."
            or "Historical observation; not guaranteed to be listed now."
    end
    if source.kind == "Vendor" then lines[#lines+1]="Recorded stock and price; recheck vendor requirements." end
    if source.verified then lines[#lines+1]="Data checked: " .. source.verified end
    if source.provider then lines[#lines+1]="Item data: " .. source.provider .. (source.dataBuild and (" · " .. source.dataBuild) or "") end
    if source.url then lines[#lines+1]="Source: " .. source.url end
    return table.concat(lines,"\n")
end
function O.Init(panel)
    O.panel=panel
    panel.scroll:ClearAllPoints()
    panel.scroll:SetPoint("TOPLEFT",16,-171)
    panel.scroll:SetPoint("BOTTOMRIGHT",-32,82)
    panel.content:SetWidth(388)
    panel.body:SetWidth(380)
    O.divider=panel:CreateTexture(nil,"ARTWORK")
    O.divider:SetHeight(1)
    O.divider:SetPoint("TOPLEFT",16,-140)
    O.divider:SetPoint("TOPRIGHT",-16,-140)
    O.divider:SetColorTexture(0.65,0.52,0.27,0.65)
    O.equipped=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    O.equipped:SetPoint("TOPLEFT",14,-178)
    O.equipped:SetPoint("TOPRIGHT",-28,-178)
    O.equipped:SetHeight(68)
    O.equipped:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}})
    O.equipped:SetBackdropColor(0.08,0.07,0.04,0.95)
    O.equipped:SetBackdropBorderColor(0.65,0.52,0.27,1)
    O.equipped.name=Text(O.equipped,"GameFontNormal",370)
    O.equipped.name:SetPoint("TOPLEFT",10,-9)
    O.equipped.text=Text(O.equipped,"GameFontHighlightSmall",370)
    O.equipped.text:SetPoint("TOPLEFT",10,-37)
    local function Choose(owner,choices,current,selectValue)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(owner,function(_,root)
                for _,choice in ipairs(choices) do
                    root:CreateRadio(choice.label,function() return choice.value==current end,function() selectValue(choice.value) end)
                end
            end)
        else
            local index=0
            for i,choice in ipairs(choices) do if choice.value==current then index=i end end
            if #choices>0 then selectValue(choices[index%#choices+1].value) end
        end
    end
    O.specButton=Button(panel,"Spec: choose...",14,-32,282,function(self)
        local choices={}
        for _,guide in ipairs(G.Presets.List()) do choices[#choices+1]={label=guide.name,value=guide.id} end
        Choose(self,choices,G.Presets.Settings().guideSpec,function(id) G.Presets.ChooseSpec(id); O.inspected=nil; O.Render(true) end)
    end)
    Button(panel,"Edit weights",304,-32,120,function() O.EditWeights() end)
    O.presetButtons={}
    local modes={"Recommended","Attack","Survivability","Custom"}
    for index,mode in ipairs(modes) do
        local button=Button(panel,mode,14+(index-1)*104,-59,102,function()
            if not G.Presets.Choose(mode) then
                O.specButton:SetText("Choose your spec first")
            else O.inspected=nil; O.Render(true) end
        end)
        O.presetButtons[mode]=button
        button:SetScript("OnEnter",function(self)
            local hints={Recommended="A balanced, guide-informed sorting estimate.",Attack="Prioritises damage; healers switch to offensive spell stats.",
                Survivability="Prioritises Stamina and Armor; not a tank simulation.",Custom="Uses your saved personal stat weights."}
            GameTooltip:SetOwner(self,"ANCHOR_LEFT")
            GameTooltip:AddLine(mode)
            GameTooltip:AddLine(hints[mode],1,1,1,true)
            if mode~="Custom" then
                GameTooltip:AddLine("Preset coefficients are by Phyz, not Wowhead numeric weights.",1,0.82,0,true)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    O.sourceButton=Button(panel,"All sources",14,-88,202,function(self)
        local choices={}
        for _,name in ipairs(G.SourceCategories) do choices[#choices+1]={label=name,value=name} end
        Choose(self,choices,O.filter,function(value)
            O.filter=value; O.expanded=false; O.limit=20; O.inspected=nil; O.Render(true)
        end)
    end)
    O.modeButton=Button(panel,O.mode,222,-88,202,function(self)
        Choose(self,{{label="Best Upgrade",value="Best Upgrade"},{label="Easiest Upgrade",value="Easiest Upgrade"}},O.mode,function(value)
            O.mode=value; O.inspected=nil; O.Render(true)
        end)
    end)
    O.futureButton=Button(panel,"Future: off",14,-115,124,function()
        O.future=not O.future; O.inspected=nil; O.Render(true)
    end)
    O.backButton=Button(panel,"< Upgrades",304,-115,120,function() O.inspected=nil; O.Render(true) end)
    O.resultLabel=Text(panel,"GameFontNormalSmall",408)
    O.resultLabel:SetPoint("TOPLEFT",16,-145)
    O.more=Button(panel,"Show more",0,0,380,function() O.expanded=true; O.limit=O.limit+20; O.Render(false) end)
    O.more:Hide()
end
function O.EditWeights()
    if not O.editor then
        local editor=CreateFrame("Frame",nil,O.panel,"BasicFrameTemplateWithInset")
        editor:EnableMouse(true)
        editor:SetPoint("TOPLEFT",10,-126)
        editor:SetSize(420,402)
        editor:SetFrameLevel(O.panel:GetFrameLevel()+30)
        editor.TitleText:SetText("Your comparison weights")
        local help=Text(editor,"GameFontHighlightSmall",382)
        help:SetPoint("TOPLEFT",14,-30)
        help:SetText("Editing saves a Custom profile. Your preset stays available.\n\nEnter stat=value pairs, for example agility=1 stamina=0.3. Unlisted stats have zero weight.\n\nThese are comparison preferences, not simulated DPS or healing. Caps and special effects are not modelled.")
        local input=CreateFrame("EditBox",nil,editor,"InputBoxTemplate")
        input:SetPoint("TOPLEFT",18,-172)
        input:SetSize(380,90)
        input:SetMultiLine(true)
        input:SetAutoFocus(false)
        input:SetMaxLetters(2000)
        input:SetScript("OnEscapePressed",function() editor:Hide() end)
        local status=Text(editor,"GameFontNormalSmall",380)
        status:SetPoint("TOPLEFT",15,-275)
        Button(editor,"Apply",14,-348,130,function()
            local ok,why=G.SetWeights(input:GetText())
            if ok then editor:Hide(); O.Render(true) else status:SetText(why) end
        end)
        Button(editor,"Cancel",156,-348,130,function() editor:Hide() end)
        editor.input,editor.status=input,status
        O.editor=editor
    end
    local profile=G.Profile()
    local keys,parts={},{}
    for key in pairs(profile.weights or {}) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do parts[#parts+1]=key .. "=" .. profile.weights[key] end
    O.editor.input:SetText(table.concat(parts," "))
    O.editor.status:SetText("Supported: strength agility stamina intellect spirit armor attackPower rangedAttackPower spellPower healing hit crit haste defense dodge parry block blockValue expertise mp5 dps")
    O.editor:Show()
end
function O.Render(resetScroll)
    local panel=O.panel
    if not panel or not O.slot or not panel:IsShown() then return end
    local result=G.Advisor.Find(O.slot,O.filter,O.mode,O.future)
    if O.inspected then
        local refreshed
        for _,row in ipairs(result.rows) do
            if G.ItemKey(row.item.link)==G.ItemKey(O.inspected.item.link) then refreshed=row; break end
        end
        O.inspected=refreshed
    end
    local gear=result.equipment[O.slot]
    panel.title:SetText(gear.label .. " — upgrades")
    panel.sourceURL=G.ResearchURL(O.slot,gear.link)
    local guide=G.Presets.Selected()
    local active=G.Presets.Settings().preset or "Custom"
    O.specButton:SetText(guide and ("Spec: " .. guide.name .. "  v") or "Choose your spec  v")
    O.sourceButton:SetText((O.filter=="All" and "All sources" or O.filter) .. "  v")
    O.modeButton:SetText(O.mode .. "  v")
    O.futureButton:SetText(O.future and "Future: on" or "Future: off")
    O.sourceButton:SetShown(not O.settingsOnly)
    O.modeButton:SetShown(not O.settingsOnly)
    O.futureButton:SetShown(not O.settingsOnly)
    O.resultLabel:ClearAllPoints()
    O.resultLabel:SetPoint("TOPLEFT",16,O.settingsOnly and -92 or -145)
    O.divider:ClearAllPoints()
    O.divider:SetPoint("TOPLEFT",16,O.settingsOnly and -87 or -140)
    O.divider:SetPoint("TOPRIGHT",-16,O.settingsOnly and -87 or -140)
    O.equipped:SetShown(not O.settingsOnly)
    panel.scroll:ClearAllPoints()
    panel.scroll:SetPoint("TOPLEFT",16,O.settingsOnly and -116 or -258)
    panel.scroll:SetPoint("BOTTOMRIGHT",-32,82)
    for mode,button in pairs(O.presetButtons) do
        if active==mode or mode~="Custom" and not guide then button:Disable() else button:Enable() end
    end
    panel.sourceLabel:SetText(result.profile.preset and "Wowhead-informed estimate · caps / effects excluded" or "Custom weights · estimated stat comparison")
    O.resultLabel:SetText(O.inspected and "Item comparison" or (#result.rows .. " upgrades · " .. result.build))
    O.backButton:SetShown(O.inspected~=nil)
    for _,row in ipairs(O.rows) do row:Hide() end
    O.more:Hide()
    local item=gear.item
    local state,reason=G.Advisor.Assess(gear)
    if O.settingsOnly then
        panel.title:SetText("Gear Review options")
        O.resultLabel:SetText("Scoring settings")
        O.backButton:Hide()
        local guide=G.Presets.Selected()
        local lines={"|cffffd100" .. result.build .. "|r",
            "Choose your intended spec and a preset above.","",
            "Recommended balances useful stats with some survivability.",
            "Attack focuses on damage. Survivability focuses on Stamina and Armor.",
            "Custom uses your own saved weights.","",
            "Use Edit weights to adjust a Custom profile. Preset coefficients remain separate."}
        if guide then lines[#lines+1]="\nGuide: Wowhead Forever · checked " .. guide.checked end
        lines[#lines+1]="\nSelect a gear card after closing this pane to inspect its upgrades."
        panel.body:SetText(table.concat(lines,"\n"))
        panel.content:SetHeight(math.max(400,panel.body:GetStringHeight()+20))
        if resetScroll then panel.scroll:SetVerticalScroll(0) end
        return
    end
    local icon=item and item.icon and ("|T" .. item.icon .. ":24|t ") or ""
    local itemColor="|cffffd100"
    if item and item.quality and C_Item and C_Item.GetItemQualityColor then
        local r,g,b=C_Item.GetItemQualityColor(item.quality)
        itemColor=("|cff%02x%02x%02x"):format(r*255,g*255,b*255)
    end
    O.equipped.name:SetText(icon .. itemColor .. (item and (item.name or item.link) or (gear.link and "Item loading" or "Empty " .. gear.label)) .. "|r")
    local summary={gear.link and "|cffaaaaaaCurrently equipped|r" or "|cffaaaaaaEquipment slot|r",
        item and (("iLvl %s · Requires %s · %s"):format(item.level or "?",item.required or "?",state)) or state}
    O.equipped.text:SetText(table.concat(summary,"\n"))
    local nameHeight=math.max(24,O.equipped.name:GetStringHeight())
    O.equipped.text:ClearAllPoints()
    O.equipped.text:SetPoint("TOPLEFT",10,-14-nameHeight)
    local summaryHeight=math.max(78,nameHeight+O.equipped.text:GetStringHeight()+23)
    O.equipped:SetHeight(summaryHeight)
    panel.scroll:SetPoint("TOPLEFT",16,-178-summaryHeight-12)
    local lines={}
    if O.inspected then
        local row=O.inspected
        lines[#lines+1]="\n|cffffd100Candidate|r  " .. (row.item.name or row.item.link)
        lines[#lines+1]=("iLvl %s · Requires %s"):format(row.item.level or "?",row.item.required or "?")
        lines[#lines+1]=("Estimated score: %.1f → %.1f  |cff40c040(%+.1f)|r"):format(row.comparison.currentScore,row.comparison.candidateScore,row.comparison.delta)
        lines[#lines+1]="\n|cffffd100Stat comparison — current → candidate|r"
        local stats={}
        for stat,delta in pairs(row.comparison.changes) do if delta~=0 then stats[#stats+1]=stat end end
        table.sort(stats,function(a,b)
            local wa,wb=result.profile.weights[a] or 0,result.profile.weights[b] or 0
            if wa~=wb then return wa>wb end
            return a<b
        end)
        for _,stat in ipairs(stats) do
            local delta=row.comparison.changes[stat]
            local after=row.item.stats[stat] or 0
            lines[#lines+1]=("%s: %g → %g  %s(%+g)|r"):format(StatName(stat),after-delta,after,delta>0 and "|cff40c040" or "|cffff6060",delta)
        end
        lines[#lines+1]=#row.comparison.replaced>1 and "Comparison replaces main hand AND off hand." or "Comparison replaces the selected slot."
        lines[#lines+1]=row.future>0 and ("Future item: " .. row.future .. " more levels needed") or "Client confirms usable now; inspect restrictions before buying."
        lines[#lines+1]=row.access
        if row.comparison.cautions and #row.comparison.cautions>0 then lines[#lines+1]=row.comparison.cautions[1] end
        lines[#lines+1]="\n|cffffd100How to get it|r"
        for _,source in ipairs(row.sources) do lines[#lines+1]="\n" .. SourceLines(source) end
        if result.profile.guide then lines[#lines+1]="\n" .. result.profile.guide.note end
        panel.sourceURL=row.source.url or G.ResearchURL(O.slot,row.item.link)
    else
        if result.reason then lines[#lines+1]="\n" .. result.reason end
        if result.reason then
            local reasons={}
            for why,count in pairs(result.skipped) do reasons[#reasons+1]=why .. " (" .. count .. ")" end
            table.sort(reasons)
            for index,why in ipairs(reasons) do if index<=3 then lines[#lines+1]=why end end
        end
    end
    panel.body:SetText(table.concat(lines,"\n"))
    local y=panel.body:GetStringHeight()+14
    local counts,hidden={},0
    if not O.inspected then
        for rank,candidate in ipairs(result.rows) do
            local kind=candidate.source.kind
            counts[kind]=(counts[kind] or 0)+1
            if rank>O.limit or (not O.expanded and (kind=="Dungeon" or kind=="Raid") and counts[kind]>3) then
                hidden=hidden+1
            else
                local index=rank
                local row=O.rows[index]
                if not row then
                    row=CreateFrame("Button",nil,panel.content)
                    row:SetSize(380,62)
                    row:EnableMouse(true)
                    local background=row:CreateTexture(nil,"BACKGROUND")
                    background:SetAllPoints()
                    background:SetColorTexture(0,0,0,0.45)
                    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
                    row.text=Text(row,"GameFontHighlightSmall",366)
                    row.text:SetPoint("TOPLEFT",7,-6)
                    row:SetScript("OnClick",function(self) O.inspected=self.candidate; O.Render(true) end)
                    row:SetScript("OnEnter",function(self)
                        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
                        GameTooltip:SetHyperlink(self.candidate.item.link)
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
                    O.rows[index]=row
                end
                row.candidate=candidate
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",0,-y)
                local icon=candidate.item.icon and ("|T" .. candidate.item.icon .. ":18|t ") or ""
                local r,g,b=1,0.82,0
                if candidate.item.quality and C_Item and C_Item.GetItemQualityColor then r,g,b=C_Item.GetItemQualityColor(candidate.item.quality) end
                local color=("|cff%02x%02x%02x"):format(r*255,g*255,b*255)
                row.text:SetTextColor(1,1,1)
                row.text:SetText(icon .. rank .. ". " .. color .. (candidate.item.name or candidate.item.link) .. "|r"
                    .. ("\n|cff40c040%+.1f estimated points|r · Requires %s%s\n%s: %s"):format(candidate.comparison.delta,
                        candidate.item.required or "?",candidate.future>0 and " · Future" or "",candidate.source.kind,candidate.source.source))
                local height=math.max(62,row.text:GetStringHeight()+10)
                row:SetHeight(height)
                row:Show()
                y=y+height+2
            end
        end
    end
    if hidden>0 then
        O.more:SetParent(panel.content)
        O.more:ClearAllPoints()
        O.more:SetPoint("TOPLEFT",0,-y)
        O.more:SetText("Show more (" .. hidden .. " remaining)")
        O.more:Show()
        y=y+28
    end
    panel.content:SetHeight(math.max(400,y+12))
    if resetScroll then panel.scroll:SetVerticalScroll(0) end
end
function O.Open(slot)
    O.settingsOnly=false
    O.slot,O.inspected,O.expanded,O.limit=slot,nil,false,20
    O.panel:Show()
    O.Render(true)
end
function O.OpenSettings()
    O.slot=O.slot or 5
    O.inspected=nil
    O.settingsOnly=true
    O.panel:Show()
    O.Render(true)
end
