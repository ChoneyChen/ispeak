#!/usr/bin/env python3
"""Create the full, non-personal 700-card native iPhone edition."""
import argparse
import subprocess
import sys
from pathlib import Path
from validate_curriculum import ROOT

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True);p.add_argument('--pdf',action='store_true');p.add_argument('--build',action='store_true');p.add_argument('--run',action='store_true');p.add_argument('--simulator');a=p.parse_args()
    if a.out.exists():p.error('output exists; choose a new folder')
    a.out.mkdir(parents=True)
    def run(script,*args):subprocess.run([sys.executable,str(ROOT/'scripts'/script),*map(str,args)],check=True)
    run('validate_curriculum.py',ROOT/'assets/general-curriculum.json','--mode','full')
    run('render_book.py',ROOT/'assets/general-curriculum.json','--out',a.out/'Book',*(['--pdf'] if a.pdf else []))
    run('scaffold_app.py','--curriculum',a.out/'Book/curriculum.json','--out',a.out/'App','--bundle-id','org.example.iSpeakGeneral','--app-name','句屿 通用版',*(['--guide',a.out/'Book/Guide.pdf'] if a.pdf else []))
    if a.build or a.run:run('project.py','run' if a.run else 'build','--project',a.out/'App',*(['--simulator',a.simulator] if a.simulator else []))
    print('General edition ready. All first-person examples are practice scenarios, not claims about the learner.')

if __name__=='__main__':main()
