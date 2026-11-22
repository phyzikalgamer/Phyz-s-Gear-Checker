"""Runtime tests use fictional fixtures only; no fixture items ship in the addon."""
import copy
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/releases/lua-runtime'))
sys.path.insert(0,str(Path(__file__).parent))
from lupa.lua51 import LuaRuntime
from import_database import generate, validate

MOCK = r'''
state={level=35,class="HUNTER",money=10000,equipped={},items={},completed={}}
function UnitLevel() return state.level end
function UnitClass() return state.class,state.class end
function UnitName(unit) return unit=="npc" and "Fixture vendor" or "Fixture player" end
function GetRealmName() return "Fixture realm" end
function UnitFactionGroup() return "Horde" end
function GetMoney() return state.money end
function GetInventoryItemLink(_,slot) return state.equipped[slot] end
function GetInventoryItemTexture() return 1 end
function GetMoneyString(value) return tostring(value).." copper" end
function GetCursorPosition() return 10,20 end
function UnitRace() return "Orc","Orc" end
function CanDualWield() return state.dualWield~=false end
function time() return 100000 end
function GetBuildInfo() return "1.60.1","71037",nil,16001 end
function GetTime() return state.clock or 0 end
function InCombatLockdown() return state.combat or false end
date=os.date
UISpecialFrames={}
SlashCmdList={}
ITEM_SPELL_TRIGGER_ONEQUIP="Equip:"
Enum={TooltipDataLineType={ItemSpellTriggerOnUse=44,ItemSpellTriggerOnEquip=45,ItemSpellTriggerOnProc=46}}
C_Timer={After=function(_,callback) callback() end}
C_QuestLog={IsQuestFlaggedCompleted=function(id) return state.completed[id] or false end}
local function Frame(withTitle)
 local f={shown=true,scripts={},width=300,height=300,level=1}
 local methods={}
 function methods:SetScript(name,fn) self.scripts[name]=fn end
 function methods:HookScript(name,fn) self.scripts[name]=fn end
 function methods:GetScript(name) return self.scripts[name] end
 function methods:GetFrameLevel() return self.level end
 function methods:SetFrameLevel(value) self.level=value end
 function methods:EnableMouse(value) self.mouseEnabled=value end
 function methods:SetSize(w,h) self.width=w; self.height=h end
 function methods:SetWidth(w) self.width=w end
 function methods:SetHeight(h) self.height=h end
 function methods:GetWidth() return self.width end
 function methods:GetHeight() return self.height end
 function methods:GetEffectiveScale() return 1 end
 function methods:GetCenter() return 100,100 end
 function methods:SetText(text) self.text=text end
 function methods:GetText() return self.text or "" end
 function methods:GetStringHeight() return math.ceil(#(self.text or "")/40)*14 end
 function methods:IsShown() return self.shown end
 function methods:Show() local old=self.shown; self.shown=true; if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
 function methods:Hide() local old=self.shown; self.shown=false; if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
 function methods:SetShown(value) if value then self:Show() else self:Hide() end end
 function methods:CreateTexture() return Frame(false) end
 function methods:CreateFontString() return Frame(false) end
 setmetatable(f,{__index=function(_,key) return methods[key] or function() end end})
 if withTitle then f.TitleText=Frame(false) end
 return f
end
function CreateFrame() return Frame(true) end
UIParent=CreateFrame(); UIParent:SetSize(1920,1080)
Minimap=CreateFrame()
GameTooltip=CreateFrame()
function issecretvalue(value) return type(value)=="table" and value.secret==true end
local function item(link) return state.items[link] end
C_Item={
 GetItemInfo=function(link)
  local i=item(link); if not i or i.loading then return nil end
  return i.name,link,2,i.level or 30,i.required or 20,"Armor","Leather",1,i.loc,1,0,i.classID or 4,1,i.binding or 2
 end,
 GetItemStats=function(link) local i=item(link); return i and not i.noStats and i.stats or nil end,
 IsUsableItem=function(link) local i=item(link); return i and i.usable~=false and (i.required or 0)<=state.level and (not i.class or i.class==state.class) or false end,
 GetItemUniquenessByID=function(link) local i=item(link); return i and i.unique or false end,
 GetItemUniqueness=function(link) local i=item(link); return i and i.category or 0,1 end,
 GetItemSpell=function(link) local i=item(link); return i and i.spell end,
 GetItemQualityColor=function() return 0,1,0 end,
 RequestLoadItemDataByID=function() end,
}
C_TooltipInfo={GetHyperlink=function(link)
 local i=item(link); if not i or i.loading then return nil end
 return {lines=i.effect and {{type=44,leftText="Synthetic effect"}} or {}}
end,GetInventoryItem=function() return {lines={}} end}
function fixture(id,loc,agi,ilvl,required)
 local link="item:"..id
 state.items[link]={name="Fixture "..id,loc=loc,stats={ITEM_MOD_AGILITY_SHORT=agi},level=ilvl or 30,required=required or 20}
 return link
end
function observe(link,kind,name)
 G.Record({link=link,kind=kind or "Vendor",source=name or "Fixture source",seen=time(),realm=GetRealmName(),faction="Horde"})
end
'''

class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCK)
        self.g=self.lua.table()
        self.lua.globals().G=self.g
        for filename in ('Core.lua','Data.lua','Scoring.lua','Presets.lua','Advisor.lua','Database.lua','Diagnostics.lua','Learner.lua','Options.lua','UI.lua'):
            source=(ROOT/'PhyzGear'/filename).read_text(encoding='utf-8')
            self.lua.execute('return function(...)\n'+source+'\nend')('PhyzGear',self.g)
        self.lua.execute('''
          state.equipped[5]=fixture(1,"INVTYPE_CHEST",5,50)
          observe(fixture(2,"INVTYPE_CHEST",10,20))
          observe(fixture(3,"INVTYPE_CHEST",1,90))
          assert(G.SetWeights("agility=1"))
        ''')

    def run_lua(self,source): self.lua.execute(source)

    def learner_fixture(self):
        self.run_lua('''
          state.requests={}
          C_Item.DoesItemExistByID=function(id) return state.items["item:"..id]~=nil end
          C_Item.GetItemInfoInstant=function(id)
            local i=state.items["item:"..id]; if i then return id,"Armor","Leather",i.loc,1,i.classID or 4,1 end
          end
          C_Item.RequestLoadItemDataByID=function(id) state.requests[#state.requests+1]=id end
          G.Learner.limit=12
        ''')

    def test_client_catalogue_discovers_green_items_without_sources(self):
        self.learner_fixture()
        self.run_lua('''
          fixture(8,"INVTYPE_CHEST",25)
          state.items["item:8"].binding=1
          G.Learner.SetActive(true)
          for i=1,8 do G.Learner.Tick() end
          assert(PhyzGearDB.items["item:8"].origin=="client")
          local result=G.Advisor.Find(5,"All")
          assert(result.rows[1].item.id==8 and result.rows[1].source.kind=="Unknown")
          local vendors=G.Advisor.Find(5,"Vendors")
          for _,row in ipairs(vendors.rows) do assert(row.item.id~=8,"Unknown acquisition leaked into Vendors") end
          assert(PhyzGearDB.learning.cursor==13)
        ''')

    def test_learner_pauses_and_resumes_saved_queue(self):
        self.learner_fixture()
        self.run_lua('''
          G.Learner.Tick(); assert(not PhyzGearDB.learning or PhyzGearDB.learning.cursor==1)
          G.Learner.SetActive(true); state.combat=true
          G.Learner.Tick(); assert(PhyzGearDB.learning.cursor==1)
          state.combat=false; G.Learner.TogglePause()
          G.Learner.Tick(); assert(PhyzGearDB.learning.cursor==1)
          G.Learner.TogglePause(); G.Learner.Tick()
          assert(PhyzGearDB.learning.cursor==13)
          G.Learner.SetActive(false)
          local learned=PhyzGearDB.learning.learned
          G.Learner.Tick(); assert(PhyzGearDB.learning.learned==learned)
        ''')

    def test_learner_throttle_timeout_and_manual_retry(self):
        self.learner_fixture()
        self.run_lua('''
          for id=1,12 do fixture(id,"INVTYPE_CHEST",id); state.items["item:"..id].loading=true end
          G.Data.Initialize(); state.requests={}
          G.Learner.SetActive(true); G.Learner.Tick()
          assert(#state.requests==2)
          G.Learner.Tick(); assert(#state.requests==4)
          for i=1,8 do G.Learner.Tick() end
          assert(#state.requests==12)
          state.clock=11; G.Learner.Tick()
          assert(next(G.Learner.pending)==nil)
          assert(next(G.Data.observedPending)==nil)
          assert(PhyzGearDB.learning.failed[8])
          state.items["item:8"].loading=false
          G.AdvisorCommand("scan retry")
          for i=1,8 do G.Learner.Tick() end
          assert(PhyzGearDB.items["item:8"])
        ''')

    def test_learner_build_change_requeues_observed_items(self):
        self.learner_fixture()
        self.run_lua('''
          G.Data.Observe("item:1","Equipped")
          G.Learner.Status()
          PhyzGearDB.learning.cursor=13
          GetBuildInfo=function() return "1.60.1","99999" end
          G.Learner.Status()
          assert(PhyzGearDB.learning.cursor==1 and PhyzGearDB.learning.queue[1])
        ''')

    def test_learner_filters_local_index_and_bounds_outstanding_requests(self):
        self.learner_fixture()
        self.run_lua('''
          G.Data.Initialize(); state.requests={}
          G.Learner.limit=100
          for id=10,60 do fixture(id,"INVTYPE_CHEST",id); state.items["item:"..id].loading=true end
          fixture(70,"",1); fixture(71,"INVTYPE_BODY",1)
          fixture(72,"INVTYPE_CHEST",1); state.items["item:72"].classID=0
          G.Learner.SetActive(true)
          for i=1,50 do G.Learner.Tick() end
          assert(#state.requests==20)
          assert(not PhyzGearDB.learning.queue[70] and not PhyzGearDB.learning.queue[71] and not PhyzGearDB.learning.queue[72])
        ''')

    def test_learner_restart_resumes_persisted_requests(self):
        self.learner_fixture()
        self.run_lua('''
          fixture(8,"INVTYPE_CHEST",25); state.items["item:8"].loading=true
          G.Learner.SetActive(true)
          for i=1,8 do G.Learner.Tick() end
          assert(PhyzGearDB.learning.queue[8])
        ''')
        source=(ROOT/'PhyzGear/Learner.lua').read_text(encoding='utf-8')
        self.lua.execute('return function(...)\n'+source+'\nend')('PhyzGear',self.g)
        self.run_lua('''
          G.Learner.limit=12; G.Learner.SetActive(true)
          state.items["item:8"].loading=false
          G.Learner.Tick()
          assert(PhyzGearDB.items["item:8"] and not PhyzGearDB.learning.queue[8])
        ''')

    def test_scan_notice_only_while_scanning(self):
        self.learner_fixture()
        self.run_lua('''
          G.Learner.SetActive(true); assert(G.Learner.IsScanning())
          G.Learner.TogglePause(); assert(not G.Learner.IsScanning())
          G.Learner.TogglePause(); state.combat=true; assert(not G.Learner.IsScanning())
          state.combat=false; G.Learner.SetActive(false); assert(not G.Learner.IsScanning())
          G.Learner.SetActive(true)
          for i=1,8 do G.Learner.Tick() end
          assert(not G.Learner.IsScanning())
        ''')

    def test_stats_override_item_level(self):
        self.run_lua('local r=G.Advisor.Find(5); assert(#r.rows==1); assert(r.rows[1].item.id==2); assert(r.rows[1].comparison.delta==5)')

    def test_no_profile_no_recommendation(self):
        self.run_lua('G.Profile().weights={}; G.InvalidateAdvisor("PROFILE"); local r=G.Advisor.Find(5); assert(#r.rows==0 and r.reason:find("weights"))')

    def test_class_and_future_filtering(self):
        self.run_lua('state.items["item:2"].class="MAGE"; observe(fixture(4,"INVTYPE_CHEST",50,100,60)); local r=G.Advisor.Find(5); assert(#r.rows==0)')

    def test_future_requires_verified_proficiency(self):
        self.run_lua('observe(fixture(4,"INVTYPE_CHEST",50,100,60)); local r=G.Advisor.Find(5,"All","Best Upgrade",true); assert(#r.rows==1); assert(r.skipped["Future proficiency requirements unknown"]==1)')

    def test_secret_stats_and_unknown_data(self):
        self.run_lua('state.items["item:2"].noStats=true; G.Data.cache={}; local r=G.Advisor.Find(5); assert(#r.rows==0); assert(r.diagnostics.unavailableData==1)')

    def test_secret_numeric_stat_is_not_treated_as_zero(self):
        self.run_lua('state.items["item:2"].stats.ITEM_MOD_AGILITY_SHORT={secret=true}; G.Data.cache={}; assert(G.Data.Item("item:2").statsKnown==false); assert(#G.Advisor.Find(5).rows==0)')

    def test_equal_and_negative_excluded(self):
        self.run_lua('state.items["item:2"].stats.ITEM_MOD_AGILITY_SHORT=5; G.Data.cache={}; assert(#G.Advisor.Find(5).rows==0)')

    def test_two_hander_replaces_both_hands(self):
        self.run_lua('''
          state.equipped[16]=fixture(10,"INVTYPE_WEAPON",8)
          state.equipped[17]=fixture(11,"INVTYPE_WEAPONOFFHAND",6)
          observe(fixture(12,"INVTYPE_2HWEAPON",12)); observe(fixture(13,"INVTYPE_2HWEAPON",20))
          local r=G.Advisor.Find(16); assert(#r.rows==1 and r.rows[1].item.id==13)
          assert(r.rows[1].comparison.delta==6 and #r.rows[1].comparison.replaced==2)
        ''')

    def test_offhand_weapon_requires_dual_wield(self):
        self.run_lua('state.dualWield=false; observe(fixture(10,"INVTYPE_WEAPONOFFHAND",20)); local r=G.Advisor.Find(17); assert(#r.rows==0 and r.skipped["Dual-wield capability not confirmed"]==1)')

    def test_player_item_use_check_takes_precedence(self):
        self.run_lua('C_PlayerInfo={CanUseItem=function(id) return id~=2 end}; assert(G.Data.Item("item:2").usable==false); assert(#G.Advisor.Find(5).rows==0)')

    def test_incomplete_one_hand_plan_excluded(self):
        self.run_lua('state.equipped[16]=fixture(10,"INVTYPE_2HWEAPON",8); observe(fixture(11,"INVTYPE_WEAPON",20)); assert(#G.Advisor.Find(16).rows==0)')

    def test_ring_replacement_is_selected_slot(self):
        self.run_lua('state.equipped[11]=fixture(10,"INVTYPE_FINGER",20); state.equipped[12]=fixture(11,"INVTYPE_FINGER",2); observe(fixture(12,"INVTYPE_FINGER",10)); assert(#G.Advisor.Find(11).rows==0); assert(G.Advisor.Find(12).rows[1].comparison.delta==8)')

    def test_unique_category_conflict(self):
        self.run_lua('state.equipped[11]=fixture(10,"INVTYPE_FINGER",2); state.items["item:10"].category=9; local l=fixture(11,"INVTYPE_FINGER",10); state.items[l].category=9; observe(l); assert(#G.Advisor.Find(12).rows==0)')

    def test_special_effects_excluded(self):
        self.run_lua('state.items["item:2"].effect=true; assert(#G.Advisor.Find(5).rows==0)')

    def test_completed_quest_excluded(self):
        self.run_lua('G.DB().sources={}; G.Data.byLink={}; G.Data.byLoc={}; G.Data.initialized=true; state.completed[100]=true; G.Record({link="item:2",kind="Quest",source="Fixture quest",questID=100,foreverVerified=true}); assert(#G.Advisor.Find(5,"Quests").rows==0)')

    def test_source_dedup_and_filter(self):
        self.run_lua('observe("item:2","Auction","Fixture auction"); local r=G.Advisor.Find(5); assert(#r.rows==1 and #r.rows[1].sources==2); assert(#G.Advisor.Find(5,"Auction House").rows==1); assert(#G.Advisor.Find(5,"Raids").rows==0)')

    def test_cache_invalidated_on_equipment_change(self):
        self.run_lua('assert(G.Advisor.Find(5).rows[1].comparison.delta==5); state.equipped[5]=fixture(9,"INVTYPE_CHEST",20); G.InvalidateAdvisor("PLAYER_EQUIPMENT_CHANGED"); assert(#G.Advisor.Find(5).rows==0)')

    def test_unknown_is_not_best_in_slot(self):
        self.run_lua('local gear=G.Equipment()[1]; gear.state="Unrated"; local status=G.Advisor.Assess(gear); assert(status=="Unrated")')

    def test_named_builds_and_legacy_saved_variables(self):
        self.run_lua('G.DB().minimapAngle=123; G.AdvisorCommand("build Healing"); assert(next(G.Profile().weights)==nil); assert(G.DB().minimapAngle==123); G.AdvisorCommand("build Custom build"); assert(G.Profile().weights.agility==1)')

    def test_invalid_weights_rejected(self):
        self.run_lua('assert(not G.SetWeights("agility=nan")); assert(not G.SetWeights("dps=9999999")); assert(not G.SetWeights("agility=1 agility=2")); assert(not G.SetWeights("fake=1"))')

    def test_missing_current_item_cache(self):
        self.run_lua('state.items["item:1"].loading=true; G.Data.cache={}; local r=G.Advisor.Find(5); assert(#r.rows==0 and r.reason:find("Equipped"))')

    def test_ah_observation_never_becomes_live_after_restart(self):
        self.run_lua('observe("item:2","Auction","Fixture auction"); local r=G.Advisor.Find(5,"Auction House"); assert(r.rows[1].ease==9); G.currentAuctionObservations={["Fixture auction"]=true}; G.InvalidateAdvisor("AH"); assert(G.Advisor.Find(5,"Auction House").rows[1].ease==2); G.InvalidateAdvisor("AUCTION_HOUSE_CLOSED"); assert(G.Advisor.Find(5,"Auction House").rows[1].ease==9)')

    def test_empty_required_slots_and_cosmetics(self):
        self.run_lua('assert(G.Equipment()[4].state=="Optional"); assert(G.Equipment()[17].state=="Optional"); assert(G.Equipment()[1].state=="Review")')

    def test_client_build_level_variations(self):
        self.run_lua('for _,level in ipairs({1,10,35,60}) do state.level=level; G.InvalidateAdvisor("PLAYER_LEVEL_UP"); for _,slot in ipairs({1,5,11,12,16,17,18}) do local r=G.Advisor.Find(slot); for _,row in ipairs(r.rows) do assert(row.item.required<=level) end end end')

    def test_ui_open_filters_compare_and_minimap_smoke(self):
        self.run_lua('G.Toggle(); G.Options.Open(5); assert(G.Options.equipped.text:GetText():find("Currently equipped")); assert(G.Options.equipped.name:GetText():find("|cff00ff00")); assert(G.Options.equipped:IsShown()); G.Options.inspected=G.Advisor.Find(5).rows[1]; G.Options.Render(true); assert(G.Options.panel.body:GetText():find("Estimated score")); G.Options.EditWeights(); G.CreateMinimap(); assert(G.minimapButton); G.Toggle()')

    def test_pane_captures_clicks(self):
        self.run_lua('G.Toggle(); G.Options.Open(5); assert(G.Options.panel.mouseEnabled==true); assert(G.Options.panel.scroll.mouseEnabled==true); assert(G.Options.panel.content.mouseEnabled==true); G.Options.EditWeights(); assert(G.Options.editor.mouseEnabled==true)')

    def test_header_cog_opens_real_settings(self):
        self.run_lua('G.Toggle(); assert(G.headerOptionsButton:IsShown()); G.headerOptionsButton:GetScript("OnClick")(); assert(G.Options.settingsOnly and G.Options.panel:IsShown()); assert(G.Options.panel.title:GetText()=="Gear Review options"); G.Options.Open(5); assert(not G.Options.settingsOnly)')

    def test_equipped_tooltip_does_not_use_global_comparison_pair(self):
        self.run_lua('local owner=CreateFrame(); G.ShowEquippedTooltip(owner,5); assert(G.equippedTooltip:IsShown()); assert(not GameTooltip:IsShown()); assert(G.equippedTooltip:GetScript("OnUpdate")==nil); assert(G.equippedTooltip~=GameTooltip)')

    def test_source_less_verified_item_is_ranked_in_all_only(self):
        self.run_lua('''
          local link=fixture(4,"INVTYPE_CHEST",30); state.items[link].binding=1
          G.Data.AddItem({id=4,name="Fixture 4",loc="INVTYPE_CHEST",required=20,level=30,
            foreverVerified=true,stats={agility=30}},"Fixture verified provider")
          local all=G.Advisor.Find(5); assert(all.rows[1].item.id==4 and all.rows[1].source.kind=="Unknown")
          assert(all.code=="UPGRADES_WITH_UNKNOWN_SOURCES")
          assert(#G.Advisor.Find(5,"Dungeons").rows==0)
          assert(G.Advisor.Find(5,"Dungeons").code=="ACQUISITION_FILTERED")
        ''')

    def test_register_database_without_acquisition_records(self):
        self.run_lua('''
          local link=fixture(4,"INVTYPE_CHEST",30); state.items[link].binding=1
          assert(G.RegisterDatabase({schema=1,game="World of Warcraft: Forever",build="test",license="Fixture",url="https://example.invalid",name="Fixture",
            items={{id=4,name="Fixture 4",loc="INVTYPE_CHEST",required=20,level=30,foreverVerified=true,stats={agility=30},sources={}}}}))
          assert(G.Data.byLoc.INVTYPE_CHEST[link]); assert(G.Advisor.Find(5).rows[1].item.id==4)
        ''')

    def test_client_bag_collection_yields_real_owned_source(self):
        self.run_lua('''
          local link=fixture(4,"INVTYPE_CHEST",30); state.items[link].binding=1
          C_Container={GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end,
            GetContainerItemLink=function() return link end}
          G.CollectOwnedItems(); G.InvalidateAdvisor("OWNED_ITEMS")
          assert(G.DB().items[link].origin=="client")
          local row=G.Advisor.Find(5).rows[1]
          assert(row.item.id==4 and row.source.kind=="Owned" and row.ease==0)
          assert(#G.Advisor.Find(5,"Quests").rows==0)
        ''')

    def test_passive_stat_line_does_not_block_static_stat_comparison(self):
        self.run_lua('''
          C_TooltipInfo.GetHyperlink=function() return {lines={{type=45,leftText="Equip: +10 Attack Power"}}} end
          state.items["item:2"].spell="Fixture passive stat"
          local row=G.Advisor.Find(5).rows[1]
          assert(row and #row.comparison.cautions>0)
        ''')

    def test_specific_empty_result_codes(self):
        self.run_lua('''
          assert(G.Advisor.Find(1).code=="NO_SLOT_RECORDS")
          G.Data.byLink={}; G.Data.byLoc={}; G.Data.entryCount=0; G.Data.indexedCount=0; G.Data.initialized=true
          G.InvalidateAdvisor("TEST"); assert(G.Advisor.Find(1).code=="DATABASE_NOT_LOADED")
          G.Data.database={}; G.InvalidateAdvisor("TEST"); assert(G.Advisor.Find(1).code=="DATABASE_EMPTY")
        ''')

    def test_developer_diagnostics_are_explicit_and_quiet(self):
        self.run_lua('''
          local output={}; print=function(message) output[#output+1]=message end
          assert(not G.debugEnabled); G.Advisor.Find(5); assert(#output==0)
          G.AdvisorCommand("debug on"); assert(G.debugEnabled)
          G.AdvisorCommand("debug report 5"); assert(#output==6)
          G.AdvisorCommand("debug off"); assert(not G.debugEnabled)
          local c=G.DatabaseCoverage(); assert(c.total>=2 and c.stats>=2)
        ''')

    def test_presets_require_explicit_spec(self):
        self.run_lua('assert(not G.Presets.Choose("Recommended")); assert(not G.Presets.ChooseSpec("made-up")); assert(G.Presets.Selected()==nil); assert(G.Profile().weights.agility==1)')

    def test_preset_switching_keeps_custom_weights(self):
        self.run_lua('assert(G.Presets.ChooseSpec("beast-mastery")); assert(G.Profile().preset=="Recommended"); assert(G.Presets.Choose("Survivability")); assert(G.Profile().weights.stamina==1 and G.Profile().weights.agility==nil); assert(G.Presets.Choose("Custom")); assert(G.Profile().weights.agility==1)')

    def test_custom_edit_does_not_modify_presets(self):
        self.run_lua('G.Presets.ChooseSpec("beast-mastery"); assert(G.SetWeights("agility=9")); assert(G.Profile().weights.agility==9); G.Presets.Choose("Recommended"); assert(G.Profile().weights.agility==1); G.Presets.Choose("Custom"); assert(G.Profile().weights.agility==9)')

    def test_ranged_hunter_dps_only_in_ranged_slot(self):
        self.run_lua('G.Presets.ChooseSpec("beast-mastery"); G.Presets.Choose("Attack"); assert(G.Profile(16).weights.dps==nil); assert(G.Profile(17).weights.dps==nil); assert(G.Profile(18).weights.dps==2)')

    def test_survivability_changes_ranking_without_damage_claim(self):
        self.run_lua('''
          state.items["item:1"].stats.ITEM_MOD_STAMINA_SHORT=1
          state.items["item:2"].stats.ITEM_MOD_STAMINA_SHORT=0
          local link=fixture(4,"INVTYPE_CHEST",1); state.items[link].stats.ITEM_MOD_STAMINA_SHORT=20; observe(link)
          G.Presets.ChooseSpec("beast-mastery"); G.Presets.Choose("Attack")
          assert(G.Advisor.Find(5).rows[1].item.id==2)
          G.Presets.Choose("Survivability"); assert(G.Advisor.Find(5).rows[1].item.id==4)
        ''')

    def test_all_28_guides_have_class_scoped_provenance(self):
        self.run_lua('''
          local count=0
          for class,guides in pairs(G.Presets.guides) do
            state.class=class
            for _,guide in ipairs(guides) do
              count=count+1; assert(guide.url:find("https://www.wowhead.com/forever/guide/classes/",1,true)==1)
              assert(guide.checked=="2026-11-22"); assert(G.Presets.ChooseSpec(guide.id))
              for _,mode in ipairs({"Recommended","Attack","Survivability"}) do
                assert(G.Presets.Choose(mode)); local profile=G.Profile(16)
                assert(profile.guide==guide and next(profile.weights))
                assert(profile.weights.hit==nil and profile.weights.expertise==nil and profile.weights.defense==nil)
              end
            end
          end
          assert(count==28)
        ''')

    def test_healer_attack_is_damage_goal_and_recommended_heals(self):
        self.run_lua('state.class="PRIEST"; G.Presets.ChooseSpec("holy"); assert(G.Profile().weights.healing==1); G.Presets.Choose("Attack"); assert(G.Profile().weights.healing==nil and G.Profile().weights.spellPower==1)')

    def test_spec_menu_and_toolbar_callbacks(self):
        self.run_lua('G.Toggle(); G.Options.Open(5); G.Options.specButton:GetScript("OnClick")(G.Options.specButton); assert(G.Presets.Selected().id=="beast-mastery"); G.Options.presetButtons.Survivability:GetScript("OnClick")(); assert(G.Profile().preset=="Survivability"); G.Options.sourceButton:GetScript("OnClick")(G.Options.sourceButton); assert(G.Options.filter=="Vendors")')

    def test_native_menu_spec_callbacks_choose_correct_entry(self):
        self.run_lua('''
          local entries={}
          MenuUtil={CreateContextMenu=function(owner,build)
            build(owner,{CreateRadio=function(_,label,selected,choose)
              entries[#entries+1]={label=label,choose=choose}
            end})
          end}
          G.Toggle(); G.Options.Open(5)
          G.Options.specButton:GetScript("OnClick")(G.Options.specButton)
          assert(#entries==3); entries[2].choose()
          assert(G.Presets.Selected().id=="marksmanship")
        ''')

    def test_auctionator_reads_only_public_price_api(self):
        self.run_lua('''
          Auctionator={API={v1={GetAuctionPriceByItemLink=function(caller,link)
            assert(caller=="PhyzGear"); return 1234 end,
            GetAuctionAgeByItemLink=function() return 2 end}}}
          local r=G.Advisor.Find(5,"Auction House")
          assert(#r.rows==1 and r.rows[1].source.price==1234 and r.rows[1].source.ageDays==2)
          assert(r.rows[1].source.seen==nil and r.rows[1].ease==9)
        ''')

    def test_easiest_ranking_separate_from_stat_strength(self):
        self.run_lua('''
          observe(fixture(4,"INVTYPE_CHEST",20),"Dungeon","Fixture boss")
          G.sessionVendors={["Fixture vendor|Fixture location"]=true}
          G.Record({link="item:2",kind="Vendor",source="Fixture vendor",location="Fixture location",seen=time(),realm=GetRealmName(),price=1})
          local best=G.Advisor.Find(5,"All","Best Upgrade")
          local easy=G.Advisor.Find(5,"All","Easiest Upgrade")
          assert(best.rows[1].item.id==4 and easy.rows[1].item.id==2)
        ''')

    def test_dungeon_default_three_and_expand(self):
        self.run_lua('''
          for id=20,24 do observe(fixture(id,"INVTYPE_CHEST",id),"Dungeon","Fixture dungeon "..id) end
          G.Toggle(); G.Options.filter="Dungeons"; G.Options.Open(5)
          local shown=0; for _,row in pairs(G.Options.rows) do if row:IsShown() then shown=shown+1 end end
          assert(shown==3 and G.Options.more:IsShown())
          G.Options.expanded=true; G.Options.Render(true)
          shown=0; for _,row in pairs(G.Options.rows) do if row:IsShown() then shown=shown+1 end end
          assert(shown==5)
        ''')

    def test_pending_item_enters_index_after_async_response(self):
        self.run_lua('''
          local link=fixture(4,"INVTYPE_CHEST",20); state.items[link].loading=true
          observe(link); G.Advisor.Find(5); assert(G.Data.pending[link])
          state.items[link].loading=false; G.InvalidateAdvisor("GET_ITEM_INFO_RECEIVED")
          assert(not G.Data.pending[link]); assert(G.Advisor.Find(5).rows[1].item.id==4)
        ''')

    def test_cache_avoids_rescanning_slot(self):
        self.run_lua('''
          local first=G.Advisor.Find(5)
          local original=G.Data.Item; local calls=0
          G.Data.Item=function(...) calls=calls+1; return original(...) end
          assert(G.Advisor.Find(5)==first and calls==0)
        ''')

    def test_verified_offline_future_item(self):
        self.run_lua('''
          local bundle={schema=1,game="World of Warcraft: Forever",name="Fixture database",
            build="test",license="Test fixture",url="https://example.invalid",items={
            {id=4,name="Future fixture",loc="INVTYPE_CHEST",required=60,level=65,
             stats={agility=30},foreverVerified=true,restrictionsVerified=true,allowedClasses={HUNTER=true},
             sources={{kind="Dungeon",source="Fixture dungeon",foreverVerified=true,url="https://example.invalid"}}}}}
          assert(G.RegisterDatabase(bundle))
          assert(#G.Advisor.Find(5,"Dungeons").rows==0)
          local r=G.Advisor.Find(5,"Dungeons","Best Upgrade",true)
          assert(#r.rows==1 and r.rows[1].future==25 and r.rows[1].comparison.delta==25)
        ''')

    def test_conflicting_offline_data_is_excluded(self):
        self.run_lua('''
          local a={foreverVerified=true,loc="INVTYPE_CHEST",required=20,stats={agility=10}}
          local b={foreverVerified=true,loc="INVTYPE_CHEST",required=20,stats={agility=20}}
          G.Data.Add({link="item:2",kind="Vendor",source="Fixture source",metadata=a})
          G.Data.Add({link="item:2",kind="Vendor",source="Fixture source",metadata=b})
          local r=G.Advisor.Find(5); assert(#r.rows==0 and r.skipped["Conflicting offline item records"]==1)
        ''')

    def test_selected_comparison_clears_after_equipping_upgrade(self):
        self.run_lua('''
          G.Toggle(); G.Options.Open(5); G.Options.inspected=G.Advisor.Find(5).rows[1]
          state.equipped[5]="item:2"; G.InvalidateAdvisor("PLAYER_EQUIPMENT_CHANGED")
          G.Options.Render(false); assert(G.Options.inspected==nil)
        ''')


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.bundle={'schema':1,'game':'World of Warcraft: Forever','name':'Fictional test provider',
            'url':'https://example.invalid','build':'test','license':'Test fixture only','verified':'test',
            'redistributionAllowed':True,'items':[{'id':99999999,'name':'Fictional test item',
            'loc':'INVTYPE_CHEST','level':10,'required':1,'foreverVerified':True,
            'stats':{'agility':3},'restrictionsVerified':True,'allowedClasses':{'HUNTER':True},
            'sources':[{'kind':'Vendor','source':'Fictional test vendor','foreverVerified':True,
                        'url':'https://example.invalid/item','verified':'test'}]}]}

    def test_valid_export_and_lua_escaping(self):
        self.bundle['items'][0]['name']='Quote " slash \\ newline\nUTF-8 é'
        lua=LuaRuntime()
        table=lua.execute('return '+generate(self.bundle).split('G.RegisterDatabase(',1)[1][:-2])
        self.assertEqual(table['items'][1]['name'],self.bundle['items'][0]['name'])

    def test_verified_item_can_omit_acquisition_and_restriction_metadata(self):
        item=self.bundle['items'][0]
        item.pop('sources'); item.pop('restrictionsVerified'); item.pop('allowedClasses')
        self.assertIs(validate(self.bundle),self.bundle)

    def test_rejects_classic_and_unknown_sources(self):
        for change in ('estimated','source','permission','duplicate','nan','conflict'):
            bundle=copy.deepcopy(self.bundle)
            if change=='estimated': bundle['items'][0]['estimated']=True
            if change=='source': bundle['items'][0]['sources'][0]['foreverVerified']=False
            if change=='permission': bundle['redistributionAllowed']=False
            if change=='duplicate': bundle['items'].append(copy.deepcopy(bundle['items'][0]))
            if change=='nan': bundle['items'][0]['stats']['agility']=float('nan')
            if change=='conflict': bundle['items'][0]['conflict']=True
            with self.subTest(change=change),self.assertRaises(ValueError): validate(bundle)

if __name__=='__main__': unittest.main(verbosity=2)
