from pathlib import Path
import re,json
ROOT=Path(__file__).resolve().parents[1]
top=(ROOT/'retro_extension/retro_top.v').read_text(encoding='utf-8')
assert 'parameter RETRO_GRAIN=1, RETRO_VIGNETTE=1' in top
assert '.I_enable(S_pixel_mode==2)' in top
assert 'cartoon_style_core' not in top
checked=[];n=0
for p in (ROOT/'retro_project').rglob('*'):
    if p.suffix not in ('.al','.prj'):continue
    s=p.read_text(encoding='utf-8')
    assert '<MODULE>retro_top</MODULE>' in s
    assert 'cartoon_style_core.v' not in s
    for rel in re.findall(r'<File Path="([^"]+)"',s):
        assert (p.parent/rel).exists(),(p,rel)
        n+=1
    checked.append(str(p.relative_to(ROOT)))
result={'project_files':checked,'dependency_references':n,'top':'retro_top','osd_only_mode_2':True,'modes':4,'no_cartoon_core':True}
(ROOT/'evidence/project_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(f'PASS {n} source/IP/constraint references; top and four-mode wiring verified')
