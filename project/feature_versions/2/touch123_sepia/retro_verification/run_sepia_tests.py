from pathlib import Path
from collections import deque
import sys,random,json,time,argparse,shutil,hashlib
sys.stdout.reconfigure(encoding='utf-8')
HERE=Path(__file__).resolve().parent; ROOT=HERE.parent
from sepia_model import sepia,advance,original_edge
from sim_backend import compile_and_run

def vectors(path,w,h,full=False,grain=1,vignette=1,source_pixels=None):
    rng=random.Random(20261017);pipeline=deque([(0,0,0,0,0)]*3)
    state={'active':0,'ud':0,'random':0x1ace,'frame':0,'x':0,'y':0,'pixels':0,'frames':0}
    with path.open('w',encoding='ascii') as f:
        def emit(rst=1,v=0,u=0,l=0,mode=0,data=None,edge=None,ready=1):
            nonlocal pipeline
            packed=0
            if not rst:
                pipeline=deque([(0,0,0,0,0)]*3)
                state.update(active=0,ud=0,random=0x1ace,frame=0,x=0,y=0)
                expected=(0,0,0,0,0)
            else:
                fs=u and not state['ud'];state['ud']=u
                if fs:
                    state.update(active=mode,x=0,y=0,random=0x1ace^(((state['frame']&32767)<<1)|1))
                    state['frame']=(state['frame']+1)&65535;state['frames']+=1
                values=[]
                if v:
                    for lane,c in enumerate(data):
                        state['random']=advance(state['random'])
                        if state['active']==3:
                            values.append(sepia(c,state['x']+lane,state['y'],state['random'],w,h,grain,vignette))
                        elif state['active']==1:values.append(edge[lane])
                        else:values.append(c)
                    state['x']+=4
                    if state['x']==w:state['x']=0;state['y']=(state['y']+1)%h
                    state['pixels']+=4
                    for c in values:packed=(packed<<24)|c
                expected=pipeline.popleft();pipeline.append((v,u,l,state['active'],packed))
            source=0
            for c in data or [0]*4:source=(source<<24)|c
            ev,eu,el,em,ed=expected
            f.write(f'{rst:x} {v:x} {u:x} {l:x} {mode:x} {ready:x} {source:024x} {ev:x} {eu:x} {el:x} {em:x} {ed:024x}\n')
        emit(rst=0);emit(rst=0)
        configs=[3] if source_pixels is not None else ([0,1,2,3] if full else [3,0,1,2,3,3,3,3,3,3,3,0])
        for frame,mode in enumerate(configs):
            if source_pixels is not None:
                src=source_pixels
            elif full:
                src=[((x*255//(w-1))<<16)|((y*255//(h-1))<<8)|((x*17+y*31)&255) for y in range(h) for x in range(w)]
            elif frame==0:src=[((i%256)*0x010101) for i in range(w*h)]
            elif frame in (4,5,6,7):src=[(0,0xffffff,0xff00ff,0x00ffff)[frame-4]]*(w*h)
            else:src=[rng.randrange(1<<24) for _ in range(w*h)]
            reference=original_edge(src,w,h) if mode==1 else None
            separate=frame%2
            if separate:emit(u=1,mode=mode)
            for y in range(h):
                for x in range(0,w,4):
                    i=y*w+x
                    if i and (not full) and rng.randrange(9)==0:emit(mode=rng.randrange(4),ready=rng.randrange(2))
                    emit(v=1,u=int(not separate and i==0),l=int(x==w-4),mode=mode if i==0 else rng.randrange(4),
                         data=src[i:i+4],edge=reference[i:i+4] if reference else None,ready=rng.randrange(2))
                for _ in range(2 if full else rng.randrange(4)):emit(mode=rng.randrange(4))
            for _ in range(8):emit(mode=rng.randrange(4))
        if not full:
            # Truncated sepia frame, then a new frame; frame marker in blanking.
            emit(u=1,mode=3);emit(v=1,mode=0,data=[0xff00ff]*4)
            emit(u=1,mode=2);emit(v=1,data=[0x234567]*4)
            # Mid-pipeline reset must flush all output and packing residue.
            emit(rst=0);emit(u=1,mode=3);emit(v=1,data=[0xffffff]*4)
        for _ in range(10):emit()
    return state

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--iverilog',default=shutil.which('iverilog') or 'C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe')
    ap.add_argument('--full',action='store_true');args=ap.parse_args()
    work=HERE/'sim_work';work.mkdir(exist_ok=True)
    w,h=(1280,720) if args.full else (48,24)
    filename=work/('720p.vec' if args.full else 'small.vec')
    state=vectors(filename,w,h,args.full)
    src=[ROOT/'retro_extension'/n for n in ('sepia_lut.v','sepia_core.v','retro_frame_select.v','cartoon_packer.v')]
    src += [ROOT/'user_source/hdl_source/isp/edge_detect_96.v',HERE/'sepia_modes_tb.sv']
    start=time.time()
    log=compile_and_run(ROOT,args.iverilog,'sepia_modes_tb',src,{'W':w,'H':h,'GRAIN':1,'VIGNETTE':1},[f'+VECTORS={filename}'])
    result={'test':'720p_four_modes' if args.full else 'small_four_modes','seconds':round(time.time()-start,2),'log':log,'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in src}}
    (ROOT/'evidence'/('720p_result.json' if args.full else 'small_result.json')).write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(log,flush=True)
if __name__=='__main__':main()
