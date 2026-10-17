"""Validate dependencies, the intended delta, unchanged timing constraints and hashes."""
from pathlib import Path
import argparse,hashlib,json,re,zipfile

def sha(data): return hashlib.sha256(data).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--baseline-zip',type=Path)
    args=ap.parse_args()
    root=Path(__file__).resolve().parent.parent
    name='touch6_dsi'
    projects=[root/f'td_project/{name}.al',*sorted((root/'td_project').rglob('*.prj'))]
    assert len(projects)==3
    count=0
    for project in projects:
        content=project.read_text(encoding='utf-8-sig')
        for rel in re.findall(r'\bPath="([^"]+)"',content):
            if rel=='.':continue
            assert not Path(rel).is_absolute(),f'Absolute dependency: {rel}'
            assert (project.parent/rel).is_file(),f'Missing dependency: {project}: {rel}'
            count+=1
        design_info=[block for block in re.findall(r'<FileInfo>(.*?)</FileInfo>',content,re.S) if 'Val="design_1"' in block]
        orders=[re.search(r'Name="CompileOrder" Val="([^"]+)"',block).group(1) for block in design_info]
        assert len(orders)==len(set(orders)),f'Duplicate source order: {project}'
        for module in ['rgb_to_gray_96.v','touch_mode_cycle.v','rgb_brighten_96.v','pixel_art_96.v']:
            assert module in content,f'RTL not registered: {module}'
    for run in ['syn_1','phy_1']:
        cfg=root/f'td_project/{name}_Runs/{run}/settings.cfg'
        for rel in re.findall(r'(?:\.\./)+(?:[^\s"{}]+)',cfg.read_text()):
            assert (cfg.parent/rel).exists(),f'Missing run dependency: {rel}'
    print(f'PASS portable TD references: {count}; all RTL registered, unique compile orders')
    if args.baseline_zip:
        provenance=json.loads((root/'SOURCE_PROVENANCE.json').read_text(encoding='utf-8'))
        assert sha(args.baseline_zip.read_bytes())==provenance['baseline_sha256']
        changed=[];same=0;original=set()
        with zipfile.ZipFile(args.baseline_zip) as z:
            prefix=provenance['baseline_prefix']
            for entry in z.infolist():
                rel=entry.filename.removeprefix(prefix)
                if not rel.startswith('user_source/') or entry.is_dir():continue
                original.add(rel)
                assert (root/rel).is_file(),f'Original source removed: {rel}'
                if (root/rel).read_bytes()==z.read(entry):same+=1
                else:changed.append(rel)
            old_sdc=z.read(prefix+'td_project/touch5_dsi.sdc').decode('utf-8-sig').replace('\r\n','\n')
        expected={f'user_source/hdl_source/{p}' for p in
                  ['design_top_wrapper.v','isp/isp_frame_select_96.v','isp/isp_top.v','touch/touch_mode_cycle.v']}
        added={p.relative_to(root).as_posix() for p in (root/'user_source').rglob('*') if p.is_file()}-original
        assert set(changed)==expected,f'Unexpected source delta: {changed}'
        assert added=={'user_source/hdl_source/isp/rgb_brighten_96.v','user_source/hdl_source/isp/pixel_art_96.v'},added
        assert (root/'td_project/touch6_dsi.sdc').read_text(encoding='utf-8-sig')==old_sdc,'Timing constraints changed'
        print(f'PASS negative-baseline delta: {same} unchanged files, 4 intended changes, 2 new RTL; identical timing constraints')
    manifest=root/'BUILD_MANIFEST.json'
    if manifest.exists():
        obj=json.loads(manifest.read_text(encoding='utf-8'))
        for rel,digest in obj['files'].items():
            assert sha((root/rel).read_bytes())==digest,f'Delivery hash mismatch: {rel}'
        print(f'PASS delivery SHA-256: {len(obj["files"])} files')

if __name__=='__main__': main()
