from pathlib import Path
import sys,random,time,json,hashlib,argparse,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from sim_backend import compile_and_run
from enhance_model import enhance,natural

sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent
IV='C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe'

def vectors(work,w,h,full=False,portrait=False):
    rng=random.Random(831719);prefix='portrait_' if portrait else '';ev=work/(prefix+'events.vec');ex=work/(prefix+'expected.vec')
    configs=[0,1] if portrait else ([0,1,1,0] if full else [1,0,0,0,0,1,1,1,1,1,1,1,1,1,0])
    with ev.open('w') as f,ex.open('w') as e:
        def emit(rst=1,v=0,u=0,l=0,mode=None,data=0):
            if mode is None:mode=rng.randrange(8)
            f.write(f'{rst:x} {v:x} {u:x} {l:x} {mode:x} {rng.randrange(2):x} {data:024x}\n')
        emit(rst=0);emit(rst=0)
        for frame,m in enumerate(configs):
            if portrait:img=np.asarray(Image.open(ROOT/'preview/original_720p.png').convert('RGB'))
            elif frame in (0,5):img=np.repeat((np.arange(w*h,dtype=np.uint32)%256).reshape(h,w,1),3,axis=2).astype(np.uint8)
            elif frame in (6,7,8,9):img=np.full((h,w,3),(0,255,127,1)[frame-6],np.uint8)
            elif frame==10:img=np.array([[[255,0,0],[0,255,0],[0,0,255],[255,255,255]]*(w//4)]*h,np.uint8)
            elif full:
                y,x=np.indices((h,w));img=np.stack((x*255//(w-1),y*255//(h-1),(x*17+y*31)%256),2).astype(np.uint8)
            else:img=np.array([rng.randrange(256) for _ in range(w*h*3)],np.uint8).reshape(h,w,3)
            a=img.astype(np.uint32);packed=((a[:,:,0]<<16)|(a[:,:,1]<<8)|a[:,:,2]).ravel().tolist()
            if m==1:ref=enhance(img);ref=(ref[:,:,0].astype(np.uint32)<<16)|(ref[:,:,1].astype(np.uint32)<<8)|ref[:,:,2];ref=ref.ravel().tolist()
            else:
                nr=natural(img).astype(np.uint32);ref=((nr[:,:,0]<<16)|(nr[:,:,1]<<8)|nr[:,:,2]).ravel().tolist()
            separate=frame%2
            if separate:emit(u=1,mode=m)
            for y in range(h):
                for x in range(0,w,4):
                    i=y*w+x
                    if not full and not portrait and i and rng.randrange(7)==0:emit()
                    data=0;expected=0
                    for c in packed[i:i+4]:data=(data<<24)|c
                    for c in ref[i:i+4]:expected=(expected<<24)|c
                    emit(v=1,u=int(i==0 and not separate),l=int(x==w-4),mode=m if i==0 else None,data=data)
                    e.write(f'{m:x} {int(x==w-4):x} {expected:024x}\n')
                gap=680 if portrait else (8 if full else rng.randrange(0,12))
                for _ in range(gap):emit()
            for _ in range(12*(w//4)+100):emit()
        # Abort before a second completed row, then reset while pipelines hold data.
        emit(u=1,mode=1);emit(v=1,data=int('ffffff'*4,16));emit(rst=0)
        for _ in range(30):emit()
    return ev,ex

def run(w,h,full=False,portrait=False):
    work=HERE/'sim_work';work.mkdir(exist_ok=True);events,expected=vectors(work,w,h,full,portrait)
    files=[ROOT/'enhance_extension'/n for n in ('enhance_lut.v','enhance_window.v','enhance_core.v','enhance_frame_select.v','cartoon_packer.v')]
    top='enhance_portrait_tb' if portrait else 'two_modes_tb'
    bench=HERE/(top+'.sv')
    if portrait:bench.write_text((HERE/'dual_capture_tb.sv').read_text().replace('module two_modes_tb;','module enhance_portrait_tb;'),encoding='utf-8')
    files +=[bench]
    start=time.time();args=[f'+VECTORS={events}',f'+EXPECTED={expected}'];capture=work/'enhance_pixels.hex'
    if portrait:args.extend([f'+CAPTURE={capture}',f'+RAW_CAPTURE={work / "natural_pixels.hex"}'])
    log=compile_and_run(ROOT,IV,top,files,{'W':w,'H':h},args)
    name='portrait' if portrait else ('720p' if full else f'small_{w}_{h}')
    result={'test':name,'log':log,'seconds':round(time.time()-start,2),'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
    if portrait:
        raw=bytes.fromhex(capture.read_text());natural_raw=bytes.fromhex((work/'natural_pixels.hex').read_text());src=Image.open(ROOT/'preview/original_720p.png').convert('RGB');reference=enhance(np.asarray(src))
        assert raw==reference.tobytes(),'Captured RTL image differs from reference'
        assert natural_raw==natural(np.asarray(src)).tobytes(),'Natural-mode capture differs from reference'
        natural_image=Image.frombytes('RGB',(w,h),natural_raw);natural_image.save(ROOT/'preview/natural_rtl_720p.png')
        img=Image.frombytes('RGB',(w,h),raw);img.save(ROOT/'preview/enhance_rtl_720p.png');img.crop((128,60,1152,660)).save(ROOT/'preview/enhance_rtl_dsi_crop.png')
        board=Image.new('RGB',(1536,494),'#202020');board.paste(natural_image.crop((128,60,1152,660)).resize((768,450)),(0,44));board.paste(img.crop((128,60,1152,660)).resize((768,450)),(768,44))
        draw=ImageDraw.Draw(board);font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
        draw.text((20,8),'原图 · 自然色校正',fill='white',font=font);draw.text((788,8),'图示效果 · 鲜艳版 RTL 输出',fill='white',font=font);board.save(ROOT/'preview/enhancement_comparison.png')
        result.update(pixels=w*h,natural_pixels=w*h,natural_rgb_bytes_match_reference=True,natural_output_sha256=hashlib.sha256(natural_raw).hexdigest(),rgb_bytes_match_reference=True,output_sha256=hashlib.sha256(raw).hexdigest())
    (ROOT/'evidence'/f'{name}_result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(log,flush=True)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--full',action='store_true');ap.add_argument('--portrait',action='store_true');ap.add_argument('--iverilog',default=shutil.which('iverilog') or IV);args=ap.parse_args();IV=args.iverilog
    if args.portrait:run(1280,720,portrait=True)
    elif args.full:run(1280,720,full=True)
    else:
        for w,h in ((4,1),(4,9),(12,2),(48,24)):run(w,h)
