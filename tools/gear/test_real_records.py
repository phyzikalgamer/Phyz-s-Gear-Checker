"""Private research validation against actual item exports, never bundled data.

Usage: python tools/gear/test_real_records.py path/to/items.json
Client APIs are simulated; this does not verify actual proficiency or gameplay.
"""
import argparse
import json
import sys
import time
from pathlib import Path
from test_advisor import MOCK, ROOT, LuaRuntime

SLOTS={1:'INVTYPE_HEAD',2:'INVTYPE_NECK',3:'INVTYPE_SHOULDER',5:'INVTYPE_CHEST',6:'INVTYPE_WAIST',7:'INVTYPE_LEGS',8:'INVTYPE_FEET',9:'INVTYPE_WRIST',10:'INVTYPE_HAND',11:'INVTYPE_FINGER',12:'INVTYPE_TRINKET',13:'INVTYPE_WEAPON',14:'INVTYPE_SHIELD',15:'INVTYPE_RANGED',16:'INVTYPE_CLOAK',17:'INVTYPE_2HWEAPON',20:'INVTYPE_ROBE',21:'INVTYPE_WEAPONMAINHAND',22:'INVTYPE_WEAPONOFFHAND',23:'INVTYPE_HOLDABLE',25:'INVTYPE_THROWN',26:'INVTYPE_RANGEDRIGHT'}
CLASS_IDS={'WARRIOR':1,'PALADIN':2,'HUNTER':3,'ROGUE':4,'PRIEST':5,'SHAMAN':7,'MAGE':8,'WARLOCK':9,'DRUID':11}
MAPPED={'agility':'agility','strength':'strength','stamina':'stamina','intellect':'intellect','spirit':'spirit','armor':'armor','attack_power':'attackPower','ranged_attack_power':'rangedAttackPower','spell_power':'spellPower','healing':'healing','dps':'dps'}

def main(path):
    source=json.loads(path.read_text(encoding='utf-8'))
    records=[r for r in source if r.get('item_class') in ('Armor','Weapon') and r.get('inventory_type') in SLOTS and not r.get('estimated') and not r.get('hidden') and not r.get('junk')]
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)
    g=lua.table(); lua.globals().G=g
    for name in ('Core.lua','Data.lua','Scoring.lua','Presets.lua','Advisor.lua','Database.lua','Diagnostics.lua','Options.lua','UI.lua'):
        lua.execute('return function(...)\n'+(ROOT/'PhyzGear'/name).read_text(encoding='utf-8')+'\nend')('PhyzGear',g)
    state=lua.globals().state
    for record in records:
        link='item:'+str(record['id'])
        stats={new:record[old] for old,new in MAPPED.items() if isinstance(record.get(old),(int,float))}
        metadata={'id':record['id'],'name':record['name'],'loc':SLOTS[record['inventory_type']],
            'required':record.get('required_level',0),'level':record.get('item_level',0),
            'stats':stats,'foreverVerified':True,'url':record.get('wowhead')}
        mask=record.get('class_mask',-1)
        allowed={name:mask in (-1,0) or bool(mask & (1<<(id_-1))) for name,id_ in CLASS_IDS.items()}
        tokens={g.StatTokens[k]:v for k,v in stats.items()}
        binding={'Binds when picked up':1,'Binds when equipped':2}.get(record.get('bonding'),0)
        item={'name':record['name'],'loc':metadata['loc'],'required':metadata['required'],'level':metadata['level'],
            'stats':tokens,'allowed':allowed,'binding':binding,'unique':bool(record.get('is_unique')),
            'effect':bool(record.get('effects') or record.get('item_set'))}
        state['items'][link]=lua.table_from(item,recursive=True)
        assert g.Data.AddItem(lua.table_from(metadata,recursive=True),'Research-only client-table export')
    lua.execute('C_Item.IsUsableItem=function(link) local i=state.items[link]; return i and i.allowed[state.class] and i.required<=state.level or false end')
    start=time.perf_counter(); cases=[]
    for class_,weight in [('HUNTER','agility=1 stamina=0.35'),('MAGE','intellect=1 spirit=0.35'),('WARRIOR','strength=1 stamina=0.35')]:
        state['class']=class_
        for level in (10,20,35,60):
            state['level']=level
            assert g.SetWeights(weight) is True
            for slot,loc in ((1,'INVTYPE_HEAD'),(5,'INVTYPE_CHEST'),(8,'INVTYPE_FEET'),(12,'INVTYPE_FINGER')):
                eligible=[r for r in records if SLOTS[r['inventory_type']]==loc and r.get('required_level',0)<=level
                          and state['items']['item:'+str(r['id'])]['allowed'][class_] and not r.get('effects') and not r.get('item_set')]
                if not eligible: continue
                stat={'HUNTER':'agility','MAGE':'intellect','WARRIOR':'strength'}[class_]
                baseline=min(eligible,key=lambda r:r.get(stat,0)+r.get('stamina',0)*0.35)
                state['equipped']=lua.table_from({slot:'item:'+str(baseline['id'])})
                g.InvalidateAdvisor('PLAYER_EQUIPMENT_CHANGED')
                result=g.Advisor.Find(slot)
                for row in result['rows'].values():
                    assert row['comparison']['delta']>0 and row['item']['required']<=level
                    assert row['source']['kind'] in ('Unknown','Auction')
                vendors=g.Advisor.Find(slot,'Vendors')
                assert len(vendors['rows'])==0
                cases.append({'class':class_,'level':level,'slot':slot,'upgrades':len(result['rows']),
                    'unknown_acquisition':result['diagnostics']['sourceUnknown']})
    output={'actual_records':len(records),'cases':len(cases),'cases_with_upgrades':sum(c['upgrades']>0 for c in cases),
            'elapsed_seconds':round(time.perf_counter()-start,3),'data_bundled':False,'sample_cases':cases[:8]}
    print(json.dumps(output,indent=2))
    return output

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('items',type=Path)
    main(parser.parse_args().items)
