from pathlib import Path
import argparse,hashlib,json,re,zipfile
sha=lambda data:hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--baseline-zip',type=Path);args=p.parse_args()
 root=Path(__file__).resolve().parent.parent;name='wb_ui_dsi';refs=0
 required=['wb_balance_96.v','wb_gain_lut.v','wb_ratio_seq.v','camera_gain_apply.v','gt911_pointer.v','touch_coord_map.v','config_mailbox.v','wb_ui_control.v','wb_ui_overlay.v','wb_ui_font.v','frame_stream_fifo.v','camera_frame_check.v','red_target_detect.v','red_target_video.v','target_ascii_font.v','red_shape_classify.v','wb_tint_96.v']
 projects=[root/f'td_project/{name}.al',*sorted((root/'td_project').rglob('*.prj'))];assert len(projects)==3
 for project in projects:
  t=project.read_text(encoding='utf-8-sig')
  for rel in re.findall(r'\bPath="([^"]+)"',t):
   if rel=='.':continue
   assert not Path(rel).is_absolute(),rel
   assert (project.parent/rel).is_file(),rel;refs+=1
  for f in required:assert f in t,f
  for f in ['edge_detect_96.v','pixel_art_96.v','touch_mode_cycle.v']:assert f not in t,f
  design=[b for b in re.findall(r'<FileInfo>(.*?)</FileInfo>',t,re.S) if 'Val="design_1"' in b]
  orders=[re.search(r'Name="CompileOrder" Val="([^"]+)"',b).group(1) for b in design]
  assert len(orders)==len(set(orders)),project
 print(f'PASS portable project: {refs} relative dependencies, WB/target/UI/frame protection modules, unique compile order')
 if args.baseline_zip:
  provenance=json.loads((root/'SOURCE_PROVENANCE.json').read_text(encoding='utf-8'));assert sha(args.baseline_zip.read_bytes())==provenance['baseline_sha256']
  allowed={'target/red_target_detect.v','target/red_target_video.v','target/target_ascii_font.v','ui/wb_ui_overlay.v','ui/wb_ui_font.v','ui/wb_ui_font.hex'}
  with zipfile.ZipFile(args.baseline_zip) as z:
   prefix=provenance['baseline_prefix'];unchanged=0
   for entry in z.namelist():
    if not entry.startswith(prefix+'user_source/') or entry.endswith('/'):continue
    rel=entry[len(prefix):];short=rel.removeprefix('user_source/hdl_source/')
    if short in allowed:continue
    assert (root/rel).read_bytes()==z.read(entry),f'Unexpected modification: {rel}';unchanged+=1
   old_sdc=z.read(prefix+f'td_project/{name}.sdc').decode('utf-8-sig').replace('\r\n','\n')
   expected_sdc=old_sdc
   assert (root/f'td_project/{name}.sdc').read_text(encoding='utf-8-sig')==expected_sdc,'Unexpected timing constraint change'
  print(f'PASS {unchanged} preserved baseline sources/assets including top, WB/tint, touch, telemetry, camera, frame protection, pins and IP; SDC unchanged')
 manifest=root/'BUILD_MANIFEST.json'
 if manifest.exists():
  obj=json.loads(manifest.read_text(encoding='utf-8'))
  for rel,h in obj['files'].items():assert sha((root/rel).read_bytes())==h,rel
  print(f'PASS delivery hashes: {len(obj["files"])} files')
if __name__=='__main__':main()
