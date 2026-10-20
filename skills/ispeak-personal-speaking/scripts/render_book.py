#!/usr/bin/env python3
"""Render one curriculum to offline HTML/Markdown and optional native macOS PDF."""
import argparse
import copy
import html
import json
import shutil
import subprocess
import sys
from pathlib import Path
from validate_curriculum import read_json, validate

CSS = '''@page{size:A4;margin:18mm}*{box-sizing:border-box}body{max-width:900px;margin:40px auto;padding:0 24px;background:#f7f5ee;color:#203e36;font:16px/1.65 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}h1{font-size:42px;line-height:1.2}h2{font-size:29px;margin-top:55px}h3{font-size:22px}.meta,.zh{color:#65756b}.point{border:1px solid #d9ddd2;border-radius:22px;padding:24px;margin:24px 0;background:white}.pattern{font-family:monospace;color:#325b4c}.example{padding:17px 0;border-top:1px solid #e1e4d8;break-inside:avoid}.en{font:22px/1.4 Georgia,serif}.zh{margin-top:8px}.badge{font-size:12px;color:#8b523d}.reference{white-space:pre-wrap}a{color:#325b4c}@media print{body{margin:0;padding:0;background:white;max-width:none;font-size:11pt}h2{break-before:page}h1,h2,h3{break-after:avoid}.point{border-radius:10px;padding:12px}.en{font-size:14pt}.example{padding:10px 0}}'''

def build(data):
    e = html.escape
    count = sum(len(g['examples']) for c in data['chapters'] for g in c['grammar'])
    h = ['<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>iSpeak · 个人口语手册</title><style>'+CSS+'</style><body>', '<h1>把句子，说成自己的。</h1>', f'<p class="meta">iSpeak · {len(data["chapters"])} 个话题 · {count} 个双语句子</p>', '<p>理解 → 跟读 → 换成自己的经历 → 开口。情境练习不代表真实经历；这些材料不构成任何考试分数保证。</p>']
    md = ['# iSpeak · 个人口语手册', f'{len(data["chapters"])} 个话题 · {count} 个双语句子', '理解 → 跟读 → 变形 → 开口。情境练习不代表真实经历。']
    blocks = [{'style':'title','text':'把句子，说成自己的。'}, {'style':'body','text':f'iSpeak · {len(data["chapters"])} 个话题 · {count} 个双语句子'}, {'style':'body','text':'理解 → 跟读 → 变形 → 开口。情境练习不代表真实经历；材料不构成任何考试分数保证。'}]
    for c in data['chapters']:
        heading=f'Part {c["part"]} / {c["id"]:02} · {c["shortTitle"]}'
        h += [f'<h2 id="chapter-{c["id"]}">{e(heading)}</h2>', f'<p>{e(c["title"])} · {e(c["subtitle"])}</p>']
        md += [f'\n## {heading}', c['title']+' · '+c['subtitle']]
        blocks += [{'style':'heading','text':heading,'key':f'C{c["id"]:02}','pageBreak':True}, {'style':'body','text':c['title']+' · '+c['subtitle']}]
        for q in c['questions']:
            h.append(f'<p>{e(q)}</p>'); md.append('- '+q); blocks.append({'style':'body','text':q})
        for g in c['grammar']:
            name=f'{g["id"]} · {g["title"]}'
            h += [f'<section class="point" id="{e(g["id"])}"><h3>{e(name)} <small>{e(g["level"])}</small></h3>',f'<p class="pattern">{e(g["pattern"])}</p>',f'<p class="meta">{e(g["note"])}</p>']
            md += [f'\n### {name} / {g["level"]}',g['pattern'],g['note']]
            blocks += [{'style':'grammar','text':name+' / '+g['level'],'key':g['id'],'keepWithNext':True}, {'style':'mono','text':g['pattern'],'keepWithNext':True}, {'style':'note','text':g['note']}]
            for s in g['examples']:
                label = '情境练习' if s.get('provenance',{}).get('type') in ('scenario','hypothetical') else ''
                h.append(f'<div class="example"><span class="badge">{e(s["kind"]+(" · "+label if label else ""))}</span><div class="en">{e(s["en"])}</div><div class="zh">{e(s["zh"])}</div></div>')
                md += [f'\n**{s["kind"]}{" · "+label if label else ""}** · {s["en"]}',s['zh']]
                blocks.append({'style':'example','text':s['kind']+(' · '+label if label else '')+'\n'+s['en']+'\n'+s['zh']})
            h.append('</section>')
        h += [f'<p>{e(c["practice"])}</p>']; md.append('\n练习：'+c['practice']); blocks.append({'style':'body','text':'练习：'+c['practice']})
    for s in data['supplements']:
        h += [f'<h2>{e(s["title"])}</h2>',f'<p class="meta">{e(s["subtitle"])}</p>',f'<div class="reference">{e(s["body"])}</div>']
        md += [f'\n## {s["title"]}',s['subtitle'],s['body']]
        blocks += [{'style':'heading','text':s['title'],'key':'S:'+s['id'],'pageBreak':True}, {'style':'note','text':s['subtitle']}, {'style':'body','text':s['body']}]
    return '\n'.join(h+['</body></html>']), '\n\n'.join(md)+'\n', blocks

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('curriculum',type=Path);p.add_argument('--out',type=Path,required=True);p.add_argument('--pdf',action='store_true');a=p.parse_args()
    data=read_json(a.curriculum);validate(data,mode='custom')
    if a.out.exists():raise SystemExit('Output folder already exists; choose a new path to preserve prior exports.')
    a.out.mkdir(parents=True);ht,md,blocks=build(data)
    (a.out/'guide.html').write_text(ht,encoding='utf-8');(a.out/'guide.md').write_text(md,encoding='utf-8')
    exported=copy.deepcopy(data)
    # An HTML-only export cannot retain source PDF page numbers.
    for c in exported['chapters']:
        c['startPage']=0
        for g in c['grammar']:g['page']=0
    for s in exported['supplements']:s['page']=0
    if a.pdf:
        swift=shutil.which('swift')
        if sys.platform!='darwin' or not swift:raise SystemExit('HTML/Markdown saved. PDF requires macOS + Swift (Xcode); no third-party service is used.')
        layout=a.out/'book-layout.json';layout.write_text(json.dumps(blocks,ensure_ascii=False),encoding='utf-8')
        subprocess.run([swift,str(Path(__file__).with_name('render_pdf.swift')),str(layout),str(a.out/'Guide.pdf'),str(a.out/'page-map.json')],check=True)
        mapping=read_json(a.out/'page-map.json')
        for c in exported['chapters']:
            c['startPage']=mapping[f'C{c["id"]:02}']
            for g in c['grammar']:g['page']=mapping[g['id']]
        for s in exported['supplements']:s['page']=mapping['S:'+s['id']]
        layout.unlink()
    (a.out/'curriculum.json').write_text(json.dumps(exported,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'folder':str(a.out),'pdf':a.pdf,'pageNumbersRebuilt':a.pdf},ensure_ascii=False))

if __name__=='__main__':main()
