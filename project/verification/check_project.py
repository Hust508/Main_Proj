"""Check portable TD file references, immutable source provenance and hashes."""
from pathlib import Path
import hashlib,json,re,argparse,zipfile

def sha(data): return hashlib.sha256(data).hexdigest()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--ex2-zip',type=Path)
    ap.add_argument('--ex3-zip',type=Path)
    args=ap.parse_args()
    root=Path(__file__).absolute().parent.parent
    count=0
    projects=[root/'td_project/lab_touch123_dsi_SC500_7inch.al',
              *list((root/'td_project').rglob('*.prj'))]
    assert len(projects)==3,'Missing TD project or run configuration'
    for project in projects:
        text=project.read_text(encoding='utf-8')
        for name in re.findall(r'\bPath="([^"]+)"',text):
            if name=='.':continue
            p=Path(name)
            assert not p.is_absolute(),f'Absolute project dependency: {name}'
            assert (project.parent/p).is_file(),f'Missing: {project}: {name}'
            count+=1
    for run in ('syn_1','phy_1'):
        p=root/f'td_project/lab_touch123_dsi_SC500_7inch_Runs/{run}/settings.cfg'
        assert p.is_file()
        for name in re.findall(r'(?:\.\./)+(?:[^\s"{}]+)',p.read_text()):
            assert (p.parent/name).exists(),f'Missing run dependency: {name}'
    for label,path,prefix in [('ex2',args.ex2_zip,'ex2_dsi/'),
      ('ex3',args.ex3_zip,'lab_ex3_osd_DSI_SC500_7inch/')]:
        if not path:continue
        with zipfile.ZipFile(path) as z:
            if label=='ex2':
                name='user_source/hdl_source/isp/edge_detect_96.v'
                assert (root/name).read_bytes()==z.read(prefix+name),'Original edge RTL changed'
            else:
                changed=[];same=0
                for name in z.namelist():
                    rel=name.removeprefix(prefix)
                    if not rel.startswith('user_source/') or name.endswith('/'):continue
                    assert (root/rel).is_file(),f'Original source missing: {rel}'
                    if z.read(name)==(root/rel).read_bytes():same+=1
                    else:changed.append(rel)
                expected={f'user_source/hdl_source/{s}' for s in
                  ('design_top_wrapper.v','video_in.v','video_out.v','isp/isp_top.v','osd/dsi_osd_overlay.v')}
                expected.add('user_source/constraints_source/pin.adc')
                assert set(changed)==expected,changed
                print(f'PASS source provenance: {same} unchanged example-3 source/IP files, {len(changed)} intentional changes')
    # Keep the v4.0.0 build manifest as historical evidence. A new source
    # snapshot validates this UI worktree without relabelling old bitstreams.
    manifest=root/'UI_WORKTREE_MANIFEST.json'
    if not manifest.is_file(): manifest=root/'BUILD_MANIFEST.json'
    if manifest.is_file():
        obj=json.loads(manifest.read_text(encoding='utf-8'))
        for name,expected in obj['files'].items():
            assert sha((root/name).read_bytes())==expected,f'Hash mismatch: {name}'
        print(f'PASS {manifest.name} SHA-256: {len(obj["files"])} files')
    print(f'PASS portable TD dependency references: {count}')

if __name__=='__main__':main()
