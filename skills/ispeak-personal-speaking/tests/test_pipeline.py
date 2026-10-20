import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from validate_curriculum import read_json,validate,validate_profile,ValidationError
from package_release import public_files

class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.data=read_json(ROOT/'assets/demo-curriculum.json')
        self.profile=read_json(ROOT/'assets/profile.example.json')

    def test_fictional_demo_and_complete_catalog(self):
        stats=validate(self.data,self.profile,'custom')
        self.assertEqual((stats['chapters'],stats['grammar'],stats['examples']),(2,3,15))
        catalog=read_json(ROOT/'assets/grammar-catalog.json')
        self.assertEqual(len(catalog['chapters']),28)
        self.assertEqual([g['id'] for c in catalog['chapters'] for g in c['grammar']],[f'G{i:03}' for i in range(1,141)])
        self.assertEqual([sum(c['part']==n for c in catalog['chapters']) for n in (1,2,3)],[12,8,8])
        refs=read_json(ROOT/'assets/reference-library.json')
        import re
        errors='\n'.join(s['body'] for s in refs if s['id'].startswith('reference-errors'))
        tenses='\n'.join(s['body'] for s in refs if s['id'].startswith('reference-tenses'))
        self.assertEqual(len(re.findall(r'(?m)^\d{2}\. ✕',errors)),45)
        self.assertEqual(len(re.findall(r'(?m)^T\d{2} ',tenses)),12)

    def test_reject_incomplete_duplicate_and_untranslated_material(self):
        mutations=[lambda d:d['chapters'][0]['grammar'][0]['examples'].clear(),lambda d:d['chapters'][0]['grammar'][0]['examples'][0].update(zh='translation'),lambda d:d['chapters'][0]['grammar'][0]['examples'][1].update(en=d['chapters'][0]['grammar'][0]['examples'][0]['en']),lambda d:d['chapters'][0]['grammar'][0]['examples'][0].update(id='wrong')]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                d=copy.deepcopy(self.data);mutate(d)
                with self.assertRaises(ValidationError):validate(d,self.profile)

    def test_general_edition_is_full_and_contains_no_personal_fact_links(self):
        data=read_json(ROOT/"assets/general-curriculum.json")
        self.assertEqual(validate(data,mode="full")["examples"],700)
        self.assertTrue(all(s["provenance"]=={"type":"scenario","factIds":[]} for c in data["chapters"] for g in c["grammar"] for s in g["examples"]))

    def test_custom_import_preserves_short_sections(self):
        data=copy.deepcopy(self.data)
        data['chapters'][0]['grammar'][0]['examples']=data['chapters'][0]['grammar'][0]['examples'][:2]
        self.assertEqual(validate(data,self.profile,'custom')['examples'],12)
        with self.assertRaises(ValidationError):validate(data,self.profile,'full')

    def test_provenance_is_required_and_unknown_or_uncertain_facts_fail(self):
        for provenance in (None,{'type':'confirmed','factIds':[]},{'type':'confirmed','factIds':['unknown']}):
            d=copy.deepcopy(self.data);d['chapters'][0]['grammar'][0]['examples'][0]['provenance']=provenance
            with self.assertRaises(ValidationError):validate(d,self.profile)
        profile=copy.deepcopy(self.profile);profile['facts'][0]['status']='uncertain'
        with self.assertRaises(ValidationError):validate(self.data,profile)
        validate(self.data,self.profile)

    def test_full_mode_enforces_all_140_definitions(self):
        cat=read_json(ROOT/'assets/grammar-catalog.json');data={'chapters':[],'supplements':[]}
        for c in cat['chapters']:
            ch=copy.deepcopy(c);ch.update(questions=['What would you say?'],practice='结构验证用测试。',startPage=0)
            for g in ch['grammar']:
                g.update(page=0,examples=[{'id':f'{g["id"]}-{n}','en':f'Structural test fixture {g["id"]} number {n}.','zh':f'结构测试第 {n} 句。','kind':'肯','provenance':{'type':'general','factIds':[]}} for n in range(1,6)])
            data['chapters'].append(ch)
        self.assertEqual(validate(data,mode='full')['examples'],700)
        data['chapters'][0]['grammar'][0]['pattern']='wrong catalog pattern'
        with self.assertRaises(ValidationError):validate(data,mode='full')

    def test_arbitrary_cwd_plan_book_and_scaffold_preserve_inputs(self):
        with tempfile.TemporaryDirectory(prefix='ispeak skill ') as directory:
            temp=Path(directory);plan=temp/'plan.json';book=temp/'Book';app=temp/'App'
            def run(script,*args):return subprocess.run([sys.executable,str(ROOT/'scripts'/script),*map(str,args)],cwd=temp,capture_output=True,text=True)
            r=run('prepare_curriculum.py','plan','--profile',ROOT/'assets/profile.example.json','--out',plan)
            self.assertEqual(r.returncode,0,r.stderr);self.assertEqual(len(read_json(plan)['chapters']),28)
            self.assertNotEqual(run('prepare_curriculum.py','plan','--profile',ROOT/'assets/profile.example.json','--out',plan).returncode,0)
            r=run('render_book.py',ROOT/'assets/demo-curriculum.json','--out',book)
            self.assertEqual(r.returncode,0,r.stderr)
            self.assertIn('environmental science', (book/'guide.html').read_text())
            r=run('scaffold_app.py','--curriculum',book/'curriculum.json','--profile',ROOT/'assets/profile.example.json','--out',app,'--bundle-id','org.example.PublicDemo','--app-name','Test App')
            self.assertEqual(r.returncode,0,r.stderr)
            self.assertTrue((app/'iSpeak.xcodeproj/project.pbxproj').is_file())
            self.assertFalse((app/'profile.private.json').exists())
            self.assertFalse((app/'App/Resources/Guide.pdf').exists())
            self.assertNotEqual(run('scaffold_app.py','--curriculum',ROOT/'assets/demo-curriculum.json','--out',app).returncode,0)
            self.assertEqual(read_json(app/'App/Resources/curriculum.json'),self.data)
            # Assembly validates completed chapter files; partial scope must be explicit.
            chapters=temp/'chapters';chapters.mkdir()
            for c in self.data['chapters']:(chapters/f'chapter-{c["id"]:02}.json').write_text(json.dumps(c))
            r=run('prepare_curriculum.py','assemble','--chapters',chapters,'--profile',ROOT/'assets/profile.example.json','--out',temp/'custom.json','--mode','custom')
            self.assertEqual(r.returncode,0,r.stderr)
            self.assertEqual(validate(read_json(temp/'custom.json'),self.profile)['examples'],15)
            self.assertNotEqual(run('prepare_curriculum.py','assemble','--chapters',chapters,'--profile',ROOT/'assets/profile.example.json','--out',temp/'full.json').returncode,0)

    def test_release_is_allowlisted_and_rejects_personal_material(self):
        paths=public_files();self.assertGreater(len(paths),20)
        self.assertFalse(any(p.suffix=='.pdf' for p in paths))
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for name in ('SKILL.md','README.md','LICENSE','assets/grammar-catalog.json','assets/demo-curriculum.json'):
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('safe')
            (root/'output').mkdir();(root/'output/profile.private.json').write_text('private user content')
            self.assertEqual(len(public_files(root)),5)
            (root/'assets/leak.txt').write_text('sample'+'@'+'invalid.test')
            with self.assertRaises(ValueError):public_files(root)
            (root/'assets/leak.txt').unlink();(root/'assets/profile.private.json').write_text('{}')
            with self.assertRaises(ValueError):public_files(root)

if __name__=='__main__':unittest.main()
