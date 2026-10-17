from pathlib import Path
import sys,time,json,hashlib,shutil,argparse
from PIL import Image,ImageDraw,ImageFont
import numpy as np
sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent
from sim_backend import compile_and_run
from run_sepia_tests import vectors
ap=argparse.ArgumentParser();ap.add_argument('--iverilog',default=shutil.which('iverilog') or 'C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe');args=ap.parse_args()
source=Image.open(ROOT/'preview/original_720p.png').convert('RGB')
a=np.asarray(source).astype(np.uint32)
pixels=((a[:,:,0]<<16)|(a[:,:,1]<<8)|a[:,:,2]).ravel().tolist()
work=HERE/'sim_work';work.mkdir(exist_ok=True)
filename=work/'portrait.vec';vectors(filename,1280,720,True,source_pixels=pixels)
bench=(HERE/'sepia_modes_tb.sv').read_text().replace('module sepia_modes_tb;','module sepia_portrait_tb;')
bench=bench.replace('integer fd,rc,','integer capture_fd;reg [4095:0] capture_name;\n    integer fd,rc,')
bench=bench.replace('fd=$fopen(filename,"r");', 'if(!$value$plusargs("CAPTURE=%s",capture_name))$fatal(1,"Missing capture");\n        capture_fd=$fopen(capture_name,"w");\n        fd=$fopen(filename,"r");')
bench=bench.replace('if(ov)pixels=pixels+4;', 'if(ov&&om==3)$fdisplay(capture_fd,"%024h",data);\n            if(ov)pixels=pixels+4;')
bench=bench.replace('$display("PASS SEPIA_FOUR_MODES', '$fclose(capture_fd);\n        $display("PASS SEPIA_PORTRAIT')
(HERE/'sepia_portrait_tb.sv').write_text(bench,encoding='utf-8')
src=[ROOT/'retro_extension'/n for n in ('sepia_lut.v','sepia_core.v','retro_frame_select.v','cartoon_packer.v')]
src += [ROOT/'user_source/hdl_source/isp/edge_detect_96.v',HERE/'sepia_portrait_tb.sv']
capture=work/'portrait_pixels.hex';start=time.time()
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in src}
log=compile_and_run(ROOT,args.iverilog,'sepia_portrait_tb',src,{'W':1280,'H':720,'GRAIN':1,'VIGNETTE':1},[f'+VECTORS={filename}',f'+CAPTURE={capture}'])
raw=bytes.fromhex(capture.read_text())
assert len(raw)==1280*720*3,len(raw)
rtl=Image.frombytes('RGB',(1280,720),raw)
reference=Image.open(ROOT/'preview/sepia_720p.png').convert('RGB')
assert rtl.tobytes()==reference.tobytes(),'RTL portrait/reference mismatch'
rtl.save(ROOT/'preview/sepia_rtl_720p.png')
rtl.crop((128,60,1152,660)).save(ROOT/'preview/sepia_rtl_dsi_crop.png')
board=Image.new('RGB',(1536,494),'#202020')
board.paste(source.crop((128,60,1152,660)).resize((768,450)),(0,44))
board.paste(rtl.crop((128,60,1152,660)).resize((768,450)),(768,44))
fontpath=Path('C:/Windows/Fonts/msyh.ttc');font=ImageFont.truetype(str(fontpath),22) if fontpath.exists() else ImageFont.load_default()
draw=ImageDraw.Draw(board);draw.text((20,8),'原图',fill='white',font=font)
draw.text((788,8),'棕褐老照片 · RTL 仿真输出',fill='white',font=font)
board.save(ROOT/'preview/portrait_comparison.png')
result={'test':'portrait_720p_rtl_capture','pixels':1280*720,'seconds':round(time.time()-start,2),'log':log,'rgb_bytes_match_reference':True,'source_sha256':hashes,'input_sha256':hashlib.sha256(source.tobytes()).hexdigest(),'output_sha256':hashlib.sha256(raw).hexdigest()}
(ROOT/'evidence/portrait_result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(log,flush=True);print('PASS portrait captured RTL output equals reference for all 921600 pixels',flush=True)
