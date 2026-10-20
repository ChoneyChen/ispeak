#!/usr/bin/env python3
"""Build a complete fictional 15-card demo without any AI API key or private input."""
import argparse
import subprocess
import sys
from pathlib import Path
from validate_curriculum import ROOT

def run(script,*args):subprocess.run([sys.executable,str(ROOT/'scripts'/script),*map(str,args)],check=True)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True);p.add_argument('--pdf',action='store_true');p.add_argument('--run',action='store_true');p.add_argument('--build',action='store_true');p.add_argument('--simulator');a=p.parse_args()
    if a.out.exists():p.error('output exists; choose a new folder')
    a.out.mkdir(parents=True)
    run('validate_curriculum.py',ROOT/'assets/demo-curriculum.json','--profile',ROOT/'assets/profile.example.json','--mode','custom')
    book=a.out/'Book';app=a.out/'App'
    run('render_book.py',ROOT/'assets/demo-curriculum.json','--out',book,*(['--pdf'] if a.pdf else []))
    run('scaffold_app.py','--curriculum',book/'curriculum.json','--profile',ROOT/'assets/profile.example.json','--out',app,'--app-name','句屿 Demo','--bundle-id','org.example.iSpeakDemo',*(['--guide',book/'Guide.pdf'] if a.pdf else []))
    if a.run or a.build:run('project.py','run' if a.run else 'build','--project',app,*(['--simulator',a.simulator] if a.simulator else []))
    print(f'Ready: {app}/iSpeak.xcodeproj\nThis demo has 15 fictional examples; full personalization is authored by the invoking AI using the shared 140-point catalog.')

if __name__=='__main__':main()
