#!/usr/bin/env python3
"""Portable local Xcode build/run/test/install helper; never embeds signing secrets."""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

def command(args, capture=False):
    return subprocess.run([str(x) for x in args],check=True,text=True,capture_output=capture).stdout if capture else subprocess.run([str(x) for x in args],check=True).returncode

def select_simulator(requested):
    listing=json.loads(command(['xcrun','simctl','list','devices','available','--json'],True))
    devices=[d for runtime,items in listing['devices'].items() if '.iOS-' in runtime for d in items if d.get('isAvailable') and 'iPhone' in d['name']]
    if requested:
        matches=[d for d in devices if requested in (d['udid'],d['name'])]
        if len(matches)!=1:raise ValueError('Simulator selection must identify exactly one available iPhone.')
        return matches[0]
    if not devices:raise ValueError('No iPhone simulator is installed. Add an iOS runtime and iPhone device in Xcode.')
    return sorted(devices,key=lambda d:(0 if '14 Pro' in d['name'] and 'Max' not in d['name'] else 1,0 if d['state']=='Booted' else 1,d['name']))[0]

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=('doctor','build','run','test','install'))
    p.add_argument('--project',type=Path);p.add_argument('--simulator');p.add_argument('--device');p.add_argument('--team');p.add_argument('--unsigned-device',action='store_true');p.add_argument('--result-path',type=Path)
    a=p.parse_args()
    if sys.platform!='darwin' or not shutil.which('xcodebuild'):raise SystemExit('Native app builds require macOS with Xcode selected via xcode-select. JSON/HTML generation works without Xcode.')
    if a.action=='doctor':
        command(['xcodebuild','-version']);command(['xcrun','simctl','list','devices','available']);return
    if not a.project:p.error('--project is required')
    root=a.project.resolve();proj=root/'iSpeak.xcodeproj';derived=root/'build'
    if not proj.is_dir():p.error('project folder must contain iSpeak.xcodeproj')
    sim=None
    if a.action=='run' and a.unsigned_device:p.error('run is for simulators; use install for a physical device')
    if a.action=='install':
        project_text=(proj/'project.pbxproj').read_text()
        if re.search(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*org\.example\.',project_text):p.error('physical installation needs a unique bundle ID; scaffold with --bundle-id first')
        if not a.team or not a.device:p.error('install requires explicit --device UDID and --team TEAMID; never reuses the author’s phone/account')
        if not re.fullmatch(r'[A-Z0-9]{10}',a.team):p.error('team must be a 10-character Apple development team ID')
        destination='id='+a.device
    elif a.unsigned_device:destination='generic/platform=iOS'
    else:
        sim=select_simulator(a.simulator);destination='id='+sim['udid']
    base=['xcodebuild','-project',str(proj),'-scheme','iSpeak','-configuration','Debug','-destination',destination,'-derivedDataPath',str(derived)]
    if a.action=='install':base+=['DEVELOPMENT_TEAM='+a.team,'CODE_SIGN_STYLE=Automatic','-allowProvisioningUpdates']
    else:base+=['CODE_SIGNING_ALLOWED=NO']
    if a.action=='test':
        if a.unsigned_device:p.error('automated UI tests require a simulator')
        command(['bash',str(root/'scripts/test_core.sh')])
        if a.result_path:base+=['-resultBundlePath',str(a.result_path.resolve())]
        command(base+['test']);return
    command(base+['build'])
    app=derived/'Build/Products'/('Debug-iphoneos' if a.action=='install' or a.unsigned_device else 'Debug-iphonesimulator')/'iSpeak.app'
    import plistlib
    with (app/'Info.plist').open('rb') as f:bundle=plistlib.load(f)['CFBundleIdentifier']
    if a.action=='install':
        if bundle.startswith('org.example.'):raise SystemExit('Unsigned example identity built, but physical installation needs a unique personal bundle ID. Scaffold a new app with --bundle-id first.')
        command(['xcrun','devicectl','device','install','app','--device',a.device,str(app)])
        command(['xcrun','devicectl','device','process','launch','--device',a.device,bundle])
        command(['xcrun','devicectl','device','info','apps','--device',a.device,'--bundle-id',bundle])
    elif a.action=='run':
        if not sim:p.error('run is for simulator; use install for a physical device')
        if sim['state']!='Booted':command(['xcrun','simctl','boot',sim['udid']])
        command(['xcrun','simctl','bootstatus',sim['udid'],'-b'])
        command(['xcrun','simctl','install',sim['udid'],str(app)])
        command(['xcrun','simctl','launch',sim['udid'],bundle])
    print(json.dumps({'app':str(app),'bundleId':bundle},ensure_ascii=False))

if __name__=='__main__':
    try:main()
    except (ValueError,subprocess.CalledProcessError) as e:raise SystemExit(str(e))
