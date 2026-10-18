from pathlib import Path
import argparse,hashlib,json,re,zipfile
sha=lambda data:hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--osd-reference',type=Path);args=p.parse_args()
 root=Path(__file__).resolve().parent.parent;name='wb_ui_dsi';refs=0
 required=['wb_balance_96.v','wb_gain_lut.v','wb_ratio_seq.v','camera_gain_apply.v','gt911_pointer.v','touch_coord_map.v','config_mailbox.v','wb_ui_control.v','wb_ui_overlay.v','wb_ui_font.v','frame_stream_fifo.v','camera_frame_check.v','red_target_detect.v','rgb_target_video.v','target_ascii_font.v','red_shape_classify.v','wb_tint_96.v','pixel_art_96.v','image_filter_bank_96.v','filter_clock_bridge.v','filter_arithmetic.v','enhance_core.v','enhance_window.v','enhance_lut.v','sepia_core.v','sepia_lut.v','dsi_osd_overlay.v','osd_logo_rom.v','osd_char_lib.v']
 projects=[root/f'td_project/{name}.al',*sorted((root/'td_project').rglob('*.prj'))];assert len(projects)==3
 for project in projects:
  t=project.read_text(encoding='utf-8-sig')
  for rel in re.findall(r'\bPath="([^"]+)"',t):
   if rel=='.':continue
   assert not Path(rel).is_absolute(),rel
   assert (project.parent/rel).is_file(),rel;refs+=1
  for f in required:assert f in t,f
  assert 'touch_mode_cycle.v' not in t
  design=[b for b in re.findall(r'<FileInfo>(.*?)</FileInfo>',t,re.S) if 'Val="design_1"' in b]
  orders=[re.search(r'Name="CompileOrder" Val="([^"]+)"',b).group(1) for b in design]
  assert len(orders)==len(set(orders)),project
 print(f'PASS portable project: {refs} relative dependencies, WB/target/UI/frame protection modules, unique compile order')
 provenance=json.loads((root/'INTEGRATION_PROVENANCE.json').read_text(encoding='utf-8'))
 for rel,h in provenance['osd_unchanged_sha256'].items():
  assert sha((root/'user_source/hdl_source'/rel).read_bytes())==h,rel
 for rel,h in provenance.get('preserved_constraints_sha256',{}).items():
  assert sha((root/rel).read_bytes())==h,rel
 sdc=(root/'td_project/wb_ui_dsi.sdc').read_bytes()
 assert sha(sdc[:provenance['sdc_base_bytes']])==provenance['sdc_base_sha256']
 assert sha(sdc)==provenance['sdc_sha256']
 assert not any(x in projects[0].read_text(encoding='utf-8') for x in ['edge_detect_96.v','cartoon_stylize_96.v','rgb_to_gray_96.v'])
 print('PASS original OSD hashes, unchanged pins/base clocks, bounded Gray CDC constraints and shared spatial filters')
 if args.osd_reference:
  assert sha(args.osd_reference.read_bytes())==provenance['osd_reference_zip_sha256']
  with zipfile.ZipFile(args.osd_reference) as z:
   for rel,h in provenance['osd_unchanged_sha256'].items():
    assert sha(z.read('lab_touch123_DSI_SC500_7inch/user_source/hdl_source/'+rel))==h,rel
  print('PASS supplied OSD archive and all four original watermark source/assets')
 manifest=root/'INTEGRATION_MANIFEST.json'
 if not manifest.exists():manifest=root/'BUILD_MANIFEST.json'
 if manifest.exists():
  obj=json.loads(manifest.read_text(encoding='utf-8'))
  for rel,h in obj['files'].items():assert sha((root/rel).read_bytes())==h,rel
  print(f'PASS delivery hashes: {len(obj["files"])} files')
if __name__=='__main__':main()
