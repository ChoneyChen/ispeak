#!/usr/bin/env python3
"""Validate curriculum structure and fact references without third-party packages."""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class ValidationError(ValueError):
    pass

def require(value, message):
    if not value:
        raise ValidationError(message)

def text_field(obj, key, where):
    require(isinstance(obj.get(key), str) and obj[key].strip(), f'{where}.{key}: expected nonempty text')

def read_json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)

def validate_profile(profile):
    require(isinstance(profile, dict) and profile.get('schemaVersion') == 1, 'profile.schemaVersion must be 1')
    require(isinstance(profile.get('facts'), list) and profile['facts'], 'profile needs at least one supplied fact')
    ids = set()
    for fact in profile['facts']:
        require(isinstance(fact, dict), 'facts must be objects')
        text_field(fact, 'id', 'fact'); text_field(fact, 'text', 'fact')
        require(fact['id'] not in ids, f'duplicate fact ID: {fact["id"]}'); ids.add(fact['id'])
        require(fact.get('status') in ('confirmed', 'uncertain'), f'{fact["id"]}: status must be confirmed or uncertain')
        require(isinstance(fact.get('topicIds'), list) and all(type(n) is int and 1 <= n <= 28 for n in fact['topicIds']), f'{fact["id"]}: topicIds must be catalog chapter numbers')
    require(isinstance(profile.get('avoid', []), list), 'profile.avoid must be a list')
    return {f['id']: f for f in profile['facts']}

def validate(data, profile=None, mode='custom'):
    require(isinstance(data, dict), 'curriculum must be an object')
    require(isinstance(data.get('chapters'), list) and data['chapters'], 'chapters must be a nonempty list')
    require(isinstance(data.get('supplements'), list), 'supplements must be a list')
    facts = validate_profile(profile) if profile is not None else None
    chapter_ids, grammar_ids, sentence_ids, english = set(), set(), set(), set()
    warnings = []
    catalog = read_json(ROOT / 'assets/grammar-catalog.json')
    expected = {g['id']: (c['id'], g) for c in catalog['chapters'] for g in c['grammar']}
    for ch in data['chapters']:
        require(isinstance(ch, dict), 'chapter must be an object')
        cid = ch.get('id')
        require(type(cid) is int and cid > 0 and cid not in chapter_ids, 'chapter IDs must be unique positive integers'); chapter_ids.add(cid)
        require(type(ch.get('part')) is int and ch['part'] in (1, 2, 3), f'chapter {cid}: part must be 1, 2 or 3')
        for key in ('title', 'subtitle', 'shortTitle', 'practice'): text_field(ch, key, f'chapter {cid}')
        require(type(ch.get('startPage')) is int and ch['startPage'] >= 0, f'chapter {cid}: startPage must be a nonnegative integer')
        require(isinstance(ch.get('questions'), list) and all(isinstance(q, str) and q.strip() for q in ch['questions']), f'chapter {cid}: questions must contain text')
        require(isinstance(ch.get('grammar'), list) and ch['grammar'], f'chapter {cid}: grammar must be nonempty')
        for g in ch['grammar']:
            require(isinstance(g, dict), f'chapter {cid}: grammar must be an object')
            for key in ('id', 'title', 'level', 'pattern', 'note'): text_field(g, key, f'chapter {cid} grammar')
            gid = g['id']; require(gid not in grammar_ids, f'duplicate grammar ID: {gid}'); grammar_ids.add(gid)
            require(type(g.get('page')) is int and g['page'] >= 0, f'{gid}: page must be nonnegative integer')
            require(isinstance(g.get('examples'), list) and g['examples'], f'{gid}: each section must have examples')
            if mode == 'full':
                require(len(g['examples']) == 5, f'{gid}: full mode requires exactly five examples')
            if mode == 'full':
                require(gid in expected and expected[gid][0] == cid, f'{gid}: not in the expected chapter')
                require(all(g[k] == expected[gid][1][k] for k in ('title', 'level', 'pattern', 'note')), f'{gid}: shared grammar definitions changed; regenerate examples, retain the catalog')
            for index, sentence in enumerate(g['examples'], 1):
                require(isinstance(sentence, dict), f'{gid}: sentence must be an object')
                for key in ('id', 'en', 'zh', 'kind'): text_field(sentence, key, gid)
                sid = sentence['id']
                require(sid == f'{gid}-{index}', f'{sid}: expected stable ID {gid}-{index}')
                require(sid not in sentence_ids, f'duplicate sentence ID: {sid}'); sentence_ids.add(sid)
                require(sentence['kind'] in ('肯', '否', '问'), f'{sid}: kind must be 肯, 否 or 问')
                require(re.search('[\u3400-\u9fff]', sentence['zh']), f'{sid}: Chinese recall cue missing')
                normalized = ' '.join(sentence['en'].casefold().split())
                require(normalized not in english, f'{sid}: duplicate English example'); english.add(normalized)
                require(not re.search(r'\[(?:TODO|INSERT|YOUR)[^\]]*\]|\{\{[^}]+\}\}', sentence['en'], re.I), f'{sid}: unfinished sentence')
                p = sentence.get('provenance')
                require(isinstance(p, dict) and p.get('type') in ('confirmed', 'general', 'scenario', 'hypothetical'), f'{sid}: valid provenance is required')
                refs = p.get('factIds')
                require(isinstance(refs, list) and all(isinstance(v, str) for v in refs) and len(refs) == len(set(refs)), f'{sid}: factIds must be unique strings')
                require(p['type'] != 'confirmed' or bool(refs), f'{sid}: confirmed statements need fact IDs')
                require(p['type'] != 'general' or not refs, f'{sid}: general statements should not claim personal facts')
                if facts is not None:
                    require(all(fid in facts for fid in refs), f'{sid}: unknown fact reference')
                    if p['type'] == 'confirmed':
                        require(all(facts[fid]['status'] == 'confirmed' for fid in refs), f'{sid}: uncertain facts cannot support confirmed claims')
                if len(sentence['en'].split()) > 45: warnings.append(f'{sid}: long spoken example; check whether every clause is needed')
    supplements = set()
    for s in data['supplements']:
        require(isinstance(s, dict), 'supplement must be an object')
        for key in ('id', 'title', 'subtitle', 'body'): text_field(s, key, 'supplement')
        require(s['id'] not in supplements, f'duplicate supplement: {s["id"]}'); supplements.add(s['id'])
        require(type(s.get('page')) is int and s['page'] >= 0, 'supplement.page must be nonnegative integer')
    if mode == 'full':
        require([c['id'] for c in data['chapters']] == list(range(1, 29)), 'full curriculum requires 28 chapters in source order')
        require(all(len(c['grammar']) == 5 for c in data['chapters']), 'full curriculum requires five grammar points per chapter')
        require([g['id'] for c in data['chapters'] for g in c['grammar']] == [f'G{i:03}' for i in range(1, 141)], 'full curriculum requires G001–G140 in order')
        require(all(c['part'] == (1 if c['id'] <= 12 else 2 if c['id'] <= 20 else 3) for c in data['chapters']), 'full curriculum Part layout must be 12/8/8')
    return {'chapters': len(chapter_ids), 'grammar': len(grammar_ids), 'examples': len(sentence_ids), 'supplements': len(supplements), 'factReferencesChecked': facts is not None, 'warnings': warnings}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('curriculum', type=Path)
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--mode', choices=('full', 'custom'), default='full')
    args = parser.parse_args()
    try:
        result = validate(read_json(args.curriculum), read_json(args.profile) if args.profile else None, args.mode)
        print(json.dumps({'status': 'valid', **result}, ensure_ascii=False))
    except (ValueError, TypeError, KeyError, OSError) as e:
        print(json.dumps({'status': 'invalid', 'error': str(e)}, ensure_ascii=False), file=sys.stderr); return 1
    return 0

if __name__ == '__main__': sys.exit(main())
