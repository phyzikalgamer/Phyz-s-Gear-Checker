"""Build an offline Lua database from a verified, normalized Forever JSON export.

Does not download data, infer Classic loot, or include API keys. See DEVELOPMENT.md.
"""
import argparse
import json
import math
from pathlib import Path

KINDS = {'Vendor', 'Auction', 'Crafted', 'Quest', 'Dungeon', 'Raid'}
LOCS = {'INVTYPE_HEAD', 'INVTYPE_NECK', 'INVTYPE_SHOULDER', 'INVTYPE_CLOAK',
        'INVTYPE_CHEST', 'INVTYPE_ROBE', 'INVTYPE_WRIST', 'INVTYPE_HAND', 'INVTYPE_WAIST',
        'INVTYPE_LEGS', 'INVTYPE_FEET', 'INVTYPE_FINGER', 'INVTYPE_TRINKET', 'INVTYPE_WEAPON',
        'INVTYPE_WEAPONMAINHAND', 'INVTYPE_WEAPONOFFHAND', 'INVTYPE_2HWEAPON', 'INVTYPE_SHIELD',
        'INVTYPE_HOLDABLE', 'INVTYPE_RANGED', 'INVTYPE_RANGEDRIGHT', 'INVTYPE_THROWN'}
STATS = {'strength','agility','stamina','intellect','spirit','armor','attackPower',
         'rangedAttackPower','spellPower','healing','hit','crit','haste','defense','dodge',
         'parry','block','blockValue','expertise','mp5','meleeHit','spellHit','rangedHit',
         'meleeCrit','spellCrit','rangedCrit','dps'}
CLASSES = {'WARRIOR','PALADIN','HUNTER','ROGUE','PRIEST','SHAMAN','MAGE','WARLOCK','DRUID'}

def number(value):
    return type(value) in (int,float) and math.isfinite(value)

def validate(bundle):
    if not isinstance(bundle,dict) or bundle.get('game') != 'World of Warcraft: Forever' or bundle.get('schema') != 1:
        raise ValueError('Expected schema 1, World of Warcraft: Forever')
    for field in ('name','url','build','license','verified'):
        if not isinstance(bundle.get(field),str) or not bundle[field].strip():
            raise ValueError('Missing provenance: ' + field)
    if bundle.get('redistributionAllowed') is not True:
        raise ValueError('Redistribution permission must be independently established')
    if not bundle['url'].startswith('https://'):
        raise ValueError('Provider URL must use HTTPS')
    if not isinstance(bundle.get('items'),list):
        raise ValueError('items must be a list')
    ids = set()
    for item in bundle['items']:
        if not isinstance(item,dict):
            raise ValueError('Item must be an object')
        item_id = item.get('id')
        if type(item_id) is not int or item_id <= 0 or item_id in ids:
            raise ValueError('Invalid or duplicate item ID')
        ids.add(item_id)
        if item.get('foreverVerified') is not True or item.get('estimated') or item.get('conflict'):
            raise ValueError('Unverified, Classic-derived or conflicting item: ' + str(item_id))
        if not isinstance(item.get('name'),str) or not item['name'] or item.get('loc') not in LOCS:
            raise ValueError('Invalid name/equipment slot')
        for field in ('level','required'):
            if not number(item.get(field)) or item[field]<0:
                raise ValueError('Missing/invalid item ' + field)
        if not isinstance(item.get('stats'),dict) or any(k not in STATS or not number(v) for k,v in item['stats'].items()):
            raise ValueError('Invalid or unsupported stats')
        if item.get('restrictionsVerified') is not True or not isinstance(item.get('allowedClasses'),dict):
            raise ValueError('Equip restrictions must be verified')
        if not item['allowedClasses'] or any(k not in CLASSES or v is not True for k,v in item['allowedClasses'].items()):
            raise ValueError('Invalid allowedClasses')
        if not isinstance(item.get('sources'),list) or not item['sources']:
            raise ValueError('Every item requires acquisition evidence')
        for source in item['sources']:
            if not isinstance(source,dict) or source.get('kind') not in KINDS or not source.get('source'):
                raise ValueError('Invalid acquisition category/source')
            if source.get('foreverVerified') is not True or not source.get('verified') or source.get('estimated'):
                raise ValueError('Acquisition needs separate Forever verification')
            if not isinstance(source.get('url'),str) or not source['url'].startswith('https://'):
                raise ValueError('Acquisition provenance URL required')
            if source.get('chance') is not None and (not number(source['chance']) or not 0 <= source['chance'] <= 100 or source.get('chanceVerified') is not True):
                raise ValueError('Drop rate requires reliable evidence')
            for field in ('price','quantity','minLevel','skill','questID','seen'):
                if source.get(field) is not None and (not number(source[field]) or source[field]<0):
                    raise ValueError('Invalid source numeric field: ' + field)
            if 'materials' in source and not isinstance(source['materials'],str):
                raise ValueError('materials must be an evidence-backed description')
    return bundle

def lua(value):
    if value is None: return 'nil'
    if value is True: return 'true'
    if value is False: return 'false'
    if number(value): return repr(value)
    if isinstance(value,str):
        # Lua 5.1 strings: preserve UTF-8 and use decimal escapes for controls.
        return '"' + ''.join('\\"' if c=='"' else '\\\\' if c=='\\' else '\\%03d'%ord(c) if ord(c)<32 else c for c in value) + '"'
    if isinstance(value,list): return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value,dict): return '{' + ','.join('['+lua(k)+']='+lua(v) for k,v in sorted(value.items())) + '}'
    raise ValueError('Unsupported JSON value')

def generate(bundle):
    validate(bundle)
    return '-- Generated from independently verified Forever evidence.\nlocal _, G = ...\nG.RegisterDatabase(' + lua(bundle) + ')\n'

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input',type=Path)
    parser.add_argument('output',type=Path)
    args = parser.parse_args()
    bundle = json.loads(args.input.read_text(encoding='utf-8'))
    rendered = generate(bundle)
    args.output.write_text(rendered,encoding='utf-8')
    print('Validated and generated',len(bundle['items']),'items:',args.output)
