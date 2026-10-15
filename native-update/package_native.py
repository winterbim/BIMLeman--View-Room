#!/usr/bin/env python3
"""Stage native binaries and their transitive DLL closure, never the .NET launcher."""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path.cwd()
OUT = ROOT / 'native-output'
STAGE = OUT / 'app'
PREFIX = Path(os.environ['MINGW_PREFIX'])
VERSION = '4.11.3'
REVISION = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
BUILD_ID = VERSION + '-' + REVISION[:8]


def copy(src, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)


STAGE.mkdir(parents=True, exist_ok=True)
for p in Path('native-build').rglob('*'):
    if p.suffix.lower() not in {'.dll', '.exe'} or 'CMakeFiles' in p.parts:
        continue
    # Veyon plugins are loaded by name; regular support libraries belong beside Master.
    dest = STAGE / ('plugins' if p.name.endswith('.dll') and 'plugins' in p.parts and not p.name.startswith('lib') and p.name != 'vnchooks.dll' else '') / p.name
    copy(p, dest)
for name in ['veyon-master.exe', 'veyon-cli.exe', 'veyon-core.dll']:
    if not (STAGE/name).is_file():
        raise SystemExit('Missing native target: '+name)
for subdir, patterns in {
    'platforms': ['qwindows.dll'], 'imageformats': ['qjpeg.dll', 'qsvg.dll'],
    'styles': ['*.dll'], 'tls': ['qopensslbackend.dll'], 'crypto': ['libqca-ossl.dll']
}.items():
    for pattern in patterns:
        found = list((PREFIX/'share/qt6/plugins'/subdir).glob(pattern))
        if not found:
            raise SystemExit(f'Missing Qt/QCA runtime plugin {subdir}/{pattern}')
        for p in found:
            copy(p, STAGE/subdir/p.name)
for folder in [Path('native-build/translations'), PREFIX/'share/qt6/translations']:
    for p in folder.glob('*.qm'):
        copy(p, STAGE/'translations'/p.name)
# Preserve upstream shipped drivers and notices as files, with no installation/service action.
shutil.copytree('upstream-veyon/3rdparty/interception', STAGE/'interception', dirs_exist_ok=True)
copy(Path('upstream-veyon/3rdparty/ddengine/ddengine64.dll'), STAGE/'ddengine64.dll')
copy(Path('upstream-veyon/COPYING'), STAGE/'COPYING')
copy(Path('upstream-veyon/README.md'), STAGE/'UPSTREAM-README.md')
copy(Path('upstream-veyon/master/data/veyon-master.ico'), STAGE/'brand.ico')
copy(Path('upstream-veyon/master/resources/bimleman-icon.png'), STAGE/'brand.png')
copy(Path('native-update/NOTICE.txt'), STAGE/'NOTICE.txt')
shutil.copytree(PREFIX/'share/licenses', STAGE/'licenses', dirs_exist_ok=True)
(STAGE/'qt.conf').write_text('[Paths]\nPrefix=.\nPlugins=.\nTranslations=translations\n', encoding='utf-8')
# Resolve imports recursively using ONLY the locked MinGW prefix, never PATH or a developer PC.
known = {p.name.lower(): p for p in (PREFIX/'bin').glob('*.dll')}
checked = set()
imports = {}
while True:
    pending = [p for p in STAGE.rglob('*') if p.suffix.lower() in {'.dll', '.exe'} and p not in checked]
    if not pending:
        break
    for binary in pending:
        checked.add(binary)
        details = subprocess.check_output(['objdump', '-p', str(binary)], text=True)
        deps = re.findall(r'DLL Name:\s+(\S+)', details)
        imports[str(binary.relative_to(STAGE))] = deps
        if any(d.lower() == 'msys-2.0.dll' for d in deps):
            raise SystemExit(f'Non-native MSYS runtime dependency: {binary}')
        for dll in deps:
            if dll.lower() in known:
                if not (STAGE/known[dll.lower()].name).exists():
                    copy(known[dll.lower()], STAGE/known[dll.lower()].name)
            elif not dll.lower().startswith(('api-ms-win-', 'ext-ms-win-')) and not (Path(os.environ['SystemRoot'])/'System32'/dll).exists() and not any(p.name.lower() == dll.lower() for p in STAGE.rglob('*.dll')):
                raise SystemExit(f'Unresolved import {dll} required by {binary}')
master_details = subprocess.check_output(['objdump', '-p', str(STAGE/'veyon-master.exe')], text=True)
if not re.search(r'Subsystem\s+00000002', master_details):
    raise SystemExit('Master is not a Windows GUI PE executable')
(OUT/'evidence/imports.json').write_text(json.dumps(imports, indent=2))
# Package all corresponding upstream and patched sources, including pinned submodules.
with tarfile.open(OUT/f'BIMLeman-{BUILD_ID}-sources.tar.gz', 'w:gz') as tar:
    def keep(info):
        return None if '.git' in Path(info.name).parts or '__pycache__' in Path(info.name).parts else info
    for folder in ['upstream-veyon', 'interception', 'native-update', 'assets/brand']:
        tar.add(folder, filter=keep)
# Bundle corresponding dependency source packages rather than relying on a web link/offer.
# Package repositories authenticate binary hashes in msys2-lock.json; downloaded source hashes
# are recorded for subsequent verification, not represented as upstream signatures.
lock = json.loads(Path('native-update/msys2-lock.json').read_text())
sources = {(p['base'], p['version']) for p in lock}
sourcedir = OUT/'dependency-sources'
sourcedir.mkdir(exist_ok=True)
def download(item):
    base, version = item
    name = f'{base}-{version}.src.tar.zst'
    url = 'https://repo.msys2.org/mingw/sources/' + name
    dest = sourcedir/name
    if not dest.exists():
        for attempt in range(3):
            try:
                urllib.request.urlretrieve(url, dest)
                break
            except Exception:
                if attempt == 2:
                    raise
    return {'name': name, 'url': url, 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    source_index = list(pool.map(download, sorted(sources)))
(sourcedir/'index.json').write_text(json.dumps(source_index, indent=2))
with tarfile.open(OUT/f'BIMLeman-{BUILD_ID}-dependency-sources.tar.gz', 'w:gz', compresslevel=1) as tar:
    tar.add(sourcedir, arcname='dependency-sources')
for script in ['Install-Safe.ps1', 'Uninstall-Safe.ps1', 'Get-VeyonInstallation.ps1']:
    copy(Path('native-update')/script, OUT/script)
# Generate uninstall list before NSIS compilation, excluding this compile-only file.
entries = sorted(STAGE.rglob('*'), key=lambda p: len(p.parts), reverse=True)
lines = []
for item in entries:
    rel = item.relative_to(STAGE).as_posix().replace('/', chr(92))
    lines.append(('RMDir' if item.is_dir() else 'Delete') + ' "$INSTDIR' + chr(92) + rel + '"')
(STAGE/'uninstall-files.nsh').write_text('\n'.join(lines), encoding='utf-8')
subprocess.run(['makensis', '-DVERSION='+VERSION, '-DBUILD_ID='+BUILD_ID,
                '-DOUTPUT='+str(OUT/f'BIMLeman-{BUILD_ID}-setup.exe'),
                '-DSTAGE='+str(STAGE), str(ROOT/'native-update/NativeMaster.nsi')], check=True)
files = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.is_file() and p.name != 'manifest.json'}
manifest = {'schema': 1, 'product': 'BIMLéman View Room', 'native': True,
            'upstreamVersion': VERSION, 'commit': REVISION, 'buildId': BUILD_ID,
            'windowsValidated': False, 'clientValidated': False, 'files': files,
            'redistributionAuthorized': os.environ.get('REDISTRIBUTION_AUTHORIZED') == 'true',
            'installer': f'BIMLeman-{BUILD_ID}-setup.exe', 'signed': False}
(OUT/'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
print('Native candidate staged. Windows tests must still validate it.')
