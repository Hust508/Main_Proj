"""Capture both adjusted modes from actual RTL on the supplied street scene."""
from pathlib import Path
import sys,time,json,hashlib,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from sim_backend import compile_and_run
from enhance_model import enhance,natural
sys.stdout.reconfigure(encoding='utf-8')
R=Path(__file__).resolve().parents[1];V=R/'enhance_verification';P=R/'preview'
work=V/'sim_work';work.mkdir(exist_ok=True)
src=Image.open(P/'slide_input.png').convert('RGB');w,h=src.size
ref,quant,edge=enhance(np.asarray(src),True);normal=natural(np.asarray(src))
events=work/'slide_events.vec';expected=work/'slide_expected.vec';capture=work/'slide_rtl.hex';raw_capture=work/'slide_natural_rtl.hex'
with events.open('w') as ev,expected.open('w') as ex:
    def emit(rst=1,v=0,u=0,l=0,m=7,d=0):ev.write(f'{rst:x} {v:x} {u:x} {l:x} {m:x} 1 {d:024x}\n')
    emit(rst=0);emit(rst=0)
    original=np.asarray(src).reshape(-1,3)
    for mode,result in ((0,normal),(1,ref)):
        emit(u=1,m=mode);emit();target=result.reshape(-1,3)
        for y in range(h):
            for x in range(0,w,4):
                i=y*w+x
                emit(v=1,l=int(x==w-4),d=int.from_bytes(original[i:i+4].tobytes(),'big'))
                ex.write(f'{mode} {int(x==w-4):x} {int.from_bytes(target[i:i+4].tobytes(),"big"):024x}\n')
            for _ in range(120):emit()
        for _ in range(w*3+100):emit()
top='style_slide_tb';bench=V/(top+'.sv')
bench.write_text((V/'dual_capture_tb.sv').read_text().replace('module two_modes_tb;','module '+top+';'),encoding='utf-8')
files=[R/'enhance_extension'/n for n in ('enhance_core.v','enhance_window.v','enhance_lut.v','enhance_frame_select.v','cartoon_packer.v')]+[bench]
iv=shutil.which('iverilog') or 'C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe'
t=time.time();log=compile_and_run(R,iv,top,files,{'W':w,'H':h},[f'+VECTORS={events}',f'+EXPECTED={expected}',f'+CAPTURE={capture}',f'+RAW_CAPTURE={raw_capture}'])
rgb=bytes.fromhex(capture.read_text());base=bytes.fromhex(raw_capture.read_text())
assert rgb==ref.tobytes() and base==normal.tobytes(),'RTL output differs from reference'
out=Image.frombytes('RGB',(w,h),rgb);nat=Image.frombytes('RGB',(w,h),base)
out.save(P/'slide_rtl_output.png');nat.save(P/'slide_natural_rtl.png')
Image.fromarray(edge).save(P/'slide_edges.png');Image.fromarray(quant).save(P/'slide_quantized.png')
try:font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
except OSError:font=ImageFont.load_default()
pair=Image.new('RGB',(2*w,h+40),'#202020');pair.paste(nat,(0,40));pair.paste(out,(w,40));d=ImageDraw.Draw(pair)
d.text((10,9),'原图 · 自然色校正',font=font,fill='white');d.text((w+10,9),'图示效果 · 鲜艳版',font=font,fill='white');pair.save(P/'slide_before_after.png')
board=Image.new('RGB',(3*w,h+40),'#202020');d=ImageDraw.Draw(board)
for i,(im,label) in enumerate(((src,'输入图像'),(nat,'新版原图 · RTL 输出'),(out,'新版图示效果 · RTL 输出'))):
    board.paste(im,(i*w,40));d.text((i*w+10,9),label,font=font,fill='white')
board.save(P/'slide_calibration_comparison.png')
inputs=[V/'enhance_model.py',P/'slide_input.png']
result={'test':'slide_scene','log':log,'seconds':round(time.time()-t,2),'pixels':w*h,'natural_pixels':w*h,'rgb_bytes_match_reference':True,'natural_rgb_bytes_match_reference':True,'output_sha256':hashlib.sha256(rgb).hexdigest(),'natural_output_sha256':hashlib.sha256(base).hexdigest(),'source_sha256':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files+inputs}}
(R/'evidence/slide_result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(log,flush=True)
