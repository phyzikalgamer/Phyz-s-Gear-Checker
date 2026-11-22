"""Mirror only this addon's sources and build a verified, standalone archive."""
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[2]
VERSION = '0.3.3'
repo = ROOT / 'tools/releases/gear-checker-repo'
shutil.copytree(ROOT / 'PhyzGear', repo / 'PhyzGear', dirs_exist_ok=True)
destination = repo / 'tools/gear'
destination.mkdir(parents=True, exist_ok=True)
for source in (ROOT / 'tools/gear').iterdir():
    if source.suffix in ('.py', '.txt'):
        shutil.copy2(source, destination / source.name)
(repo / 'README.md').write_text('''# Phyz's Gear Checker

Character-style equipment review and conservative upgrade suggestions for WoW Forever.

Download the latest preview from [Releases](https://github.com/phyzikalgamer/Phyz-s-Gear-Checker/releases), extract `PhyzGear` into Forever's `Interface/AddOns`, and fully restart WoW. Open with `/pgear` or the minimap icon.

The addon learns its own equipment catalogue from your installed client's item index and item-loading APIs while the overview is open, outside combat. Progress is saved. It includes uncommon items and shows client-data attribution separately from observed vendors, crafting and auction listings. Wowhead Forever links support further research.

Choose your spec and Recommended, Attack or Survivability, or edit Custom weights. These are sorting estimates, not simulations or authoritative Wowhead numeric weights. Unknown acquisition does not block the All filter.

See [usage and limitations](PhyzGear/README.md), [changes](PhyzGear/CHANGELOG.md), and [coverage investigation](PhyzGear/COVERAGE.md). Preview: mocked tests and static checks passed; current item learning needs in-game validation.
''', encoding='utf-8')
notes = '''Background catalogue scanning preview.

- Scanning continues after Gear Review closes and automatically pauses during combat.
- Previously started scans resume after login; progress and manual pause are saved.
- Standalone dismissible scan notice with a Pause scan button. Dismissing lets scanning continue.

Updating from 0.3.x: /reload is sufficient. Catalogue learning and saved progress are retained.

Validated: 65 Lua 5.1 mocked runtime/import tests, TOC, Forever API baseline and archive structure. Not tested in-game; background scanning still needs verification.
'''
(ROOT / f'tools/releases/gear-release-notes-{VERSION}.md').write_text(notes, encoding='utf-8')
archive = ROOT / f'tools/releases/PhyzGear-{VERSION}.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
    for source in sorted((ROOT / 'PhyzGear').rglob('*')):
        if source.is_file():
            output.write(source, 'PhyzGear/' + source.relative_to(ROOT / 'PhyzGear').as_posix())
with zipfile.ZipFile(archive) as output:
    assert output.testzip() is None
    assert 'PhyzGear/PhyzGear.toc' in output.namelist()
    assert all(name.startswith('PhyzGear/') for name in output.namelist())
    for name in output.namelist():
        assert output.read(name) == (repo / name).read_bytes()
print(f'Verified {archive.name}: {archive.stat().st_size} bytes')
