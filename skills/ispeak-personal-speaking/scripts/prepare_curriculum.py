#!/usr/bin/env python3
"""Plan fact-grounded AI authoring, or assemble completed chapter files."""
import argparse
import json
from pathlib import Path
from validate_curriculum import ROOT, read_json, validate, validate_profile

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    plan = sub.add_parser('plan'); plan.add_argument('--profile', type=Path, required=True); plan.add_argument('--out', type=Path, required=True)
    assemble = sub.add_parser('assemble'); assemble.add_argument('--chapters', type=Path, required=True); assemble.add_argument('--profile', type=Path, required=True); assemble.add_argument('--out', type=Path, required=True); assemble.add_argument('--mode', choices=('full', 'custom'), default='full'); assemble.add_argument('--extra-supplements', type=Path)
    a = p.parse_args(); profile = read_json(a.profile); facts = validate_profile(profile)
    if a.command == 'plan':
        if a.out.exists(): raise SystemExit('Refusing to overwrite an existing plan; choose a new path or edit it explicitly.')
        catalog = read_json(ROOT / 'assets/grammar-catalog.json')
        plan = {'version': 1, 'authoring': 'AI writes original bilingual examples; this plan does not manufacture personal history.', 'learning': profile.get('learning', {}), 'factIndex': profile['facts'], 'avoid': profile.get('avoid', []), 'chapters': []}
        for chapter in catalog['chapters']:
            plan['chapters'].append({**chapter, 'suggestedFactIds': [fid for fid, f in facts.items() if chapter['id'] in f['topicIds'] and f['status'] == 'confirmed'], 'examplesPerGrammar': 5, 'chapterOutput': f'chapter-{chapter["id"]:02}.json'})
        write(a.out, plan)
        print(f'Wrote {len(plan["chapters"])}-chapter / 140-point authoring plan: {a.out}')
    else:
        if a.out.exists(): raise SystemExit('Refusing to overwrite existing curriculum; choose a new path or edit it explicitly.')
        paths = sorted(a.chapters.glob('chapter-*.json'))
        chapters = [read_json(path) for path in paths]
        supplements = read_json(ROOT / 'assets/reference-library.json')
        if a.extra_supplements: supplements += read_json(a.extra_supplements)
        data = {'chapters': chapters, 'supplements': supplements}
        report = validate(data, profile, a.mode)
        write(a.out, data); print(json.dumps({'output': str(a.out), **report}, ensure_ascii=False))

if __name__ == '__main__': main()
