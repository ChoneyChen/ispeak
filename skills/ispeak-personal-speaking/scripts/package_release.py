#!/usr/bin/env python3
"""Build an allowlisted, privacy-checked skill ZIP (never copies generated user apps)."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
FILES={'SKILL.md','README.md','LICENSE'}
DIRS={'agents','scripts','references','assets','tests'}
DENY_SUFFIXES={'.mobileprovision','.p12','.p8','.key','.cer','.ipa','.xcresult','.pyc','.pdf'}
SKIP={'.DS_Store','__pycache__','build','output','DerivedData','xcuserdata','.git'}
PATTERNS=[('absolute home path',r'/Users/[A-Za-z0-9_.-]+/'),('email address',r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),('private key',r'-----BEGIN (?:[A-Z ]+ )?PRIVATE KEY-----'),('physical-device identifier',r'\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\b'),('embedded signing team',r'DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]{10}\b')]

def public_files(root=ROOT):
    paths=[]
    for p in sorted(root.rglob('*')):
        rel=p.relative_to(root)
        if any(part in SKIP for part in rel.parts):continue
        if rel.parts[0] not in DIRS and str(rel) not in FILES:continue
        if p.is_symlink():raise ValueError(f'Release refuses symbolic link: {rel}')
        if not p.is_file():continue
        if p.suffix.lower() in DENY_SUFFIXES or p.name.endswith('.private.json'):raise ValueError(f'Private/generated artifact in public tree: {rel}')
        raw=p.read_bytes()
        if p.suffix.lower() not in {'.png','.jpg','.jpeg','.ico','.car'}:
            text=raw.decode('utf-8')
            for label,pattern in PATTERNS:
                if re.search(pattern,text):raise ValueError(f'Privacy check failed ({label}): {rel}')
        paths.append(p)
    for required in ('SKILL.md','README.md','LICENSE','assets/grammar-catalog.json','assets/demo-curriculum.json'):
        if root/required not in paths:raise ValueError(f'Missing release resource: {required}')
    return paths

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    if a.out.exists():raise SystemExit('Release ZIP already exists; choose a new path.')
    paths=public_files();a.out.parent.mkdir(parents=True,exist_ok=True)
    manifest={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    with zipfile.ZipFile(a.out,'x',compression=zipfile.ZIP_DEFLATED) as z:
        for path in paths:z.write(path,arcname='ispeak-personal-speaking/'+str(path.relative_to(ROOT)))
        z.writestr('ispeak-personal-speaking/RELEASE-MANIFEST.json',json.dumps(manifest,indent=2)+'\n')
    checksum=hashlib.sha256(a.out.read_bytes()).hexdigest()
    a.out.with_suffix(a.out.suffix+'.sha256').write_text(checksum+'  '+a.out.name+'\n')
    print(json.dumps({'archive':str(a.out),'files':len(paths),'sha256':checksum}))

if __name__=='__main__':main()
