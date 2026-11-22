"""Audit public research exports without shipping those exports."""
import argparse
import json
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
research=ROOT/'tools/releases/gear-research'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--items',type=Path,default=research/'kb-items.txt')
parser.add_argument('--sources',type=Path,default=research/'kb-sources.txt')
args=parser.parse_args()
items=json.loads(args.items.read_text(encoding='utf-8'))
sources=json.loads(args.sources.read_text(encoding='utf-8'))
equipment=[i for i in items if i.get('item_class') in ('Armor','Weapon') and i.get('inventory_type',0) not in (0,4,18,19,24,28)]
visible=[i for i in equipment if not i.get('estimated') and not i.get('hidden') and not i.get('junk')]
by_id={i['id']:i for i in visible}
linked={s['item_id'] for s in sources if s['item_id'] in by_id}
stats=('agility','strength','stamina','intellect','spirit','armor','attack_power','spell_power','hit','crit','haste','dps')
result={
 'public_kb':{
  'total_items':len(items),'equipment':len(equipment),'visible_nonestimated_equipment':len(visible),
  'with_numeric_combat_stats':sum(any(isinstance(i.get(k),(int,float)) and i[k]!=0 for k in stats) for i in visible),
  'with_acquisition_links_not_independently_verified':len(linked),
  'with_verified_forever_acquisition':sum(s.get('foreverVerified') is True or s.get('seenInForever') is True for s in sources if s['item_id'] in by_id),
  'slots':dict(sorted(Counter(i.get('slot','Unknown') for i in visible).items())),
  'source_rows':dict(sorted(Counter(s['kind'] for s in sources if s['item_id'] in by_id).items())),
  'levels':dict(sorted(Counter('no requirement' if not i.get('required_level') else f"{(i['required_level']-1)//10*10+1}-{(i['required_level']-1)//10*10+10}" for i in visible).items())),
  'new_forever_equipment_count':'Not established by export; item ID alone is not evidence',
  'redistribution':'No explicit aggregate licence found; research only, not bundled',
 },
}
print(json.dumps(result,indent=2))
