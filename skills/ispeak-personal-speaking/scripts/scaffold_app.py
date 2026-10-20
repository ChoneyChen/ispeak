#!/usr/bin/env python3
"""Copy the working SwiftUI app and inject a validated, user-specific curriculum."""
import argparse
import json
import plistlib
import re
import shutil
from pathlib import Path
from validate_curriculum import ROOT, read_json, validate

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--curriculum',type=Path,required=True);p.add_argument('--profile',type=Path)
    p.add_argument('--out',type=Path,required=True);p.add_argument('--bundle-id',default='org.example.iSpeak')
    p.add_argument('--app-name',default='句屿');p.add_argument('--guide',type=Path)
    a=p.parse_args()
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9][A-Za-z0-9-]*){2,}',a.bundle_id):p.error('bundle ID needs at least three reverse-DNS components; use letters/digits/hyphens')
    if not a.app_name.strip() or len(a.app_name)>40 or any(ord(c)<32 for c in a.app_name):p.error('app-name must be 1–40 printable characters')
    if a.out.exists():p.error('output folder exists; choose a new folder. Existing apps and progress must not be overwritten implicitly.')
    data=read_json(a.curriculum);stats=validate(data,read_json(a.profile) if a.profile else None,mode='custom')
    if a.guide:
        if not a.guide.is_file() or a.guide.read_bytes()[:5]!=b'%PDF-':p.error('--guide must be a readable PDF')
        pages=[c['startPage'] for c in data['chapters']]+[g['page'] for c in data['chapters'] for g in c['grammar']]+[s['page'] for s in data['supplements']]
        if not all(n>=1 for n in pages):p.error('PDF page links are missing; pass the curriculum.json emitted by render_book.py --pdf')
    shutil.copytree(ROOT/'assets/ios-template',a.out,ignore=shutil.ignore_patterns('.DS_Store','__pycache__','xcuserdata'))
    resources=a.out/'App/Resources';resources.mkdir(exist_ok=True)
    shutil.copy2(a.curriculum,resources/'curriculum.json')
    if a.guide:shutil.copy2(a.guide,resources/'Guide.pdf')
    project=a.out/'iSpeak.xcodeproj/project.pbxproj';project.write_text(project.read_text().replace('org.example.iSpeak',a.bundle_id))
    info=a.out/'App/Info.plist'
    with info.open('rb') as f:plist=plistlib.load(f)
    plist['CFBundleDisplayName']=a.app_name
    with info.open('wb') as f:plistlib.dump(plist,f,sort_keys=False)
    shutil.copy2(ROOT/'LICENSE',a.out/'LICENSE')
    (a.out/'.gitignore').write_text('build/\nDerivedData/\nxcuserdata/\n*.xcuserstate\n*.mobileprovision\n*.p12\n*.p8\n*.private.json\n.DS_Store\n')
    (a.out/'README.md').write_text('# '+a.app_name+' · iSpeak\n\nSwiftUI / iOS 17+ / offline curriculum and local progress.\n\nOpen `iSpeak.xcodeproj`, select a simulator and Run. This project uses Xcode synchronized folders. Choose your own signing team and a unique bundle identifier for a physical device.\n\nThe source profile is intentionally excluded. `curriculum.json` still contains personalized examples: keep this generated app private unless you explicitly want to publish them.\n\nRun `bash scripts/test_core.sh` for learning, review and persistence checks. UI tests use an isolated store.\n',encoding='utf-8')
    print(json.dumps({'project':str(a.out/'iSpeak.xcodeproj'),'bundleId':a.bundle_id,'appName':a.app_name,'guideBundled':bool(a.guide),**stats},ensure_ascii=False))

if __name__=='__main__':main()
