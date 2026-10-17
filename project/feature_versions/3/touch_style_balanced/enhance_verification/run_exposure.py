"""Capture portrait detail at controlled digital input brightness; not board RAW."""
from pathlib import Path
import sys,time,json,hashlib,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from enhance_model import enhance
from sim_backend import compile_and_run
sys.stdout.reconfigure(encoding='utf-8')
R=Path(__file__).resolve().parents[1];V=R/'enhance_verification';P=R/'preview'
work=V/'sim_work';work.mkdir(exist_ok=True);w,h=320,180
base=np.asarray(Image.open(P/'original_720p.png').convert('RGB').resize((w,h),Image.Resampling.LANCZOS))
inputs=[base,base//8,base//32];refs=[enhance(a) for a in inputs]
ev=work/'exposure_events.vec';ex=work/'exposure_expected.vec';capture=work/'exposure_rtl.hex'
with ev.open('w') as f,ex.open('w') as e:
    def emit(rst=1,v=0,u=0,l=0,m=7,data=0):f.write(f'{rst:x} {v:x} {u:x} {l:x} {m:x} 1 {data:024x}\n')
    emit(rst=0);emit(rst=0)
    for source,target in zip(inputs,refs):
        emit(u=1,m=1);emit();source=source.reshape(-1,3);target=target.reshape(-1,3)
        for y in range(h):
            for x in range(0,w,4):
                i=y*w+x;emit(v=1,l=int(x==w-4),data=int.from_bytes(source[i:i+4].tobytes(),'big'))
                e.write(f'1 {int(x==w-4):x} {int.from_bytes(target[i:i+4].tobytes(),"big"):024x}\n')
            for _ in range(80):emit()
        for _ in range(1500):emit()
top='style_exposure_tb';bench=V/(top+'.sv')
bench.write_text((V/'two_modes_tb.sv').read_text().replace('module two_modes_tb;','module '+top+';'),encoding='utf-8')
files=[R/'enhance_extension'/n for n in ('enhance_core.v','enhance_window.v','enhance_lut.v','enhance_frame_select.v','cartoon_packer.v')]+[bench]
iv=shutil.which('iverilog') or 'C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe'
t=time.time();log=compile_and_run(R,iv,top,files,{'W':w,'H':h},[f'+VECTORS={ev}',f'+EXPECTED={ex}',f'+CAPTURE={capture}'])
raw=bytes.fromhex(capture.read_text());assert raw==b''.join(a.tobytes() for a in refs)
actual=np.frombuffer(raw,np.uint8).reshape(3,h,w,3)
metrics=[]
for i,a in enumerate(actual):
    region=a[20:150,122:200].astype(np.int32);luma=(region[:,:,0]+2*region[:,:,1]+region[:,:,2])//4
    unique=len(np.unique(luma));assert unique>=5,(i,unique)
    metrics.append({'brightness_divisor':[1,8,32][i],'portrait_roi_luma_levels':unique,'portrait_roi_zero_luma_fraction':float(np.mean(luma==0))})
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
board=Image.new('RGB',(w*2,h*3+36*4),'#202020');d=ImageDraw.Draw(board)
d.text((8,8),'参考图片的数字亮度测试，并非相机实拍预测',font=font,fill='white')
for i,(a,b) in enumerate(zip(inputs,actual)):
    y=36+i*(h+36);board.paste(Image.fromarray(a),(0,y+36));board.paste(Image.fromarray(b),(w,y+36))
    d.text((8,y+8),f'输入亮度 1/{[1,8,32][i]}',font=font,fill='white');d.text((w+8,y+8),'本版实际 RTL 输出',font=font,fill='white')
board.save(P/'portrait_exposure_rtl.png')
result={'test':'portrait_digital_exposure','log':log,'seconds':round(time.time()-t,2),'pixels':3*w*h,'rgb_bytes_match_reference':True,'not_board_raw':True,'digital_brightness_divisors':[1,8,32],'detail_metrics':metrics,'output_sha256':hashlib.sha256(raw).hexdigest(),'source_sha256':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files+[V/'enhance_model.py',P/'original_720p.png',Path(__file__)]}}
(R/'evidence/exposure_result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(log,flush=True)
