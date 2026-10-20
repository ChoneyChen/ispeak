#!/usr/bin/env python3
"""Install this local, public skill folder into the user's skill directory."""
import argparse
import os
import shutil
from pathlib import Path
from package_release import ROOT,public_files

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination',type=Path,default=Path(os.environ.get('CODEX_HOME',str(Path.home()/'.codex')))/'skills')
    a=parser.parse_args();target=a.destination/'ispeak-personal-speaking'
    if target.exists():raise SystemExit(f'Skill already exists at {target}. Keep it, or explicitly choose another destination after backing it up.')
    paths=public_files()
    for src in paths:
        dst=target/src.relative_to(ROOT);dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    print(f'Installed: {target}\nInvoke $ispeak-personal-speaking in a new chat after the client refreshes its skill list.')

if __name__=='__main__':main()
