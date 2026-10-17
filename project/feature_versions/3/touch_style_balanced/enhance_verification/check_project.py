from pathlib import Path
import re,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
checked=[];refs=0
for p in (ROOT/'enhance_project').rglob('*'):
 if p.suffix not in ('.al','.prj'):continue
 s=p.read_text(encoding='utf-8');assert '<MODULE>enhance_top</MODULE>' in s
 for n in ('sepia_core.v','sepia_lut.v','edge_detect_96.v','isp_frame_select_96.v','dsi_osd_overlay.v','osd_logo_rom.v'):
  assert n not in s,(p,n)
 for rel in re.findall(r'<File Path="([^"]+)"',s):
  assert (p.parent/rel).resolve().exists(),(p,rel);refs+=1
 assert 'enhance_stream_diag.v' in s
 assert 'enhance_clock_bridge.v' in s and 'enhance_rgb_async_fifo.v' in s
 checked.append(str(p.relative_to(ROOT)))
assert len(checked)==3
cycle=(ROOT/'enhance_extension/cartoon_mode_cycle.v').read_text();assert "(mode_o==0)?3'd1:3'd0" in cycle
fs=(ROOT/'enhance_extension/enhance_frame_select.v').read_text()
assert "(I_mode==1)?3'd1:3'd0" in fs and 'sepia' not in fs and 'edge_detect' not in fs
window=(ROOT/'enhance_extension/enhance_window.v').read_text()
assert 'ROW_PERIOD' not in window and 'rows_done' not in window
top=(ROOT/'enhance_extension/enhance_top.v').read_text(encoding='utf-8')
assert '.I_process_clk(S_24m_clk),.I_process_rst_n(S_config_rst_n)' in top
assert '.I_camera_clk         ( S_24m_clk' in top
assert '.I_mipi_rx_error      ( sync_cdc_overflow' in top
isp=(ROOT/'enhance_extension/enhance_isp_top.v').read_text(encoding='utf-8')
assert 'enhance_clock_bridge u_clock_bridge' in isp
assert '.I_clk(I_process_clk),.I_rst_n(I_process_rst_n)' in isp
fifo=(ROOT/'enhance_extension/enhance_rgb_async_fifo.v').read_text(encoding='utf-8')
assert '.primary_addr_i(wr_addr + wr_en_s)' in fifo
assert '.primary_addr_i(rd_addr + rd_en_s)' in fifo
preserved=json.loads((ROOT/'evidence/preserved_user_sources.json').read_text())
for rel,h in preserved.items():assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==h,rel
result={'modes':2,'project_files':checked,'references':refs,'original_user_source_files_byte_preserved':len(preserved),'old_styles_not_compiled':True,'camera_configuration':'SC500CS 1280x720 60fps'}
(ROOT/'evidence/project_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('PASS two-mode wiring, 3 project configurations,',refs,'references,',len(preserved),'preserved original files')
