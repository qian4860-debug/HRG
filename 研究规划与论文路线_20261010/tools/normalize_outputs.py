from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parent.parent.parent
REPORT = Path(__file__).resolve().parent.parent
for p in ROOT.iterdir():
    if p.is_dir() and p.name.startswith('鐮') and p.name.endswith('20261010'):
        # Only relocate our UTF-8/Windows-PowerShell mojibake output, never research sources.
        for item in p.rglob('*'):
            if item.is_file():
                dest = REPORT / item.relative_to(p)
                dest.parent.mkdir(parents=True, exist_ok=True)
                if dest.exists():
                    if dest.read_bytes() != item.read_bytes():
                        raise RuntimeError(f'Conflicting generated output: {dest}')
                    item.unlink()
                else:
                    shutil.move(str(item), str(dest))
        for child in sorted(p.rglob('*'), key=lambda x: len(x.parts), reverse=True):
            if child.is_dir():
                child.rmdir()
        p.rmdir()
for p in (REPORT / 'tools').glob('*.ps1'):
    p.write_text(p.read_text(encoding='utf-8-sig'), encoding='utf-8-sig')
print('Generated output paths normalized; source files untouched.')