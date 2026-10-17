"""RTL checks: nonzero dark detail, hue order, neutral highlights, spatial noise."""
from pathlib import Path
import sys,time,json,hashlib,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from sim_backend import compile_and_run
from enhance_model import enhance,natural
sys.stdout.reconfigure(encoding='utf-8')
R=Path(__file__).resolve().parents[1];V=R/'enhance_verification';W=256;H=160
work=V/'sim_work';work.mkdir(exist_ok=True)
colors=[(190,215,245),(245,185,185),(190,235,185),(245,235,170),
        (220,190,240),(180,235,235),(245,205,160),(210,170,130),
        (128,128,128),(255,255,255),(0,0,0),(24,24,24),
        (190,135,110),(120,80,60),(75,50,40),(230,175,145)]
base=np.empty((H,W,3),np.uint8)
for i,c in enumerate(colors):base[i//4*40:(i//4+1)*40,i%4*64:(i%4+1)*64]=c
rng=np.random.default_rng(90210)
noisy=np.clip(base.astype(np.int32)+rng.integers(-8,9,base.shape),0,255).astype(np.uint8)
dim=base//8
dim_noisy=np.clip(dim.astype(np.int32)+rng.integers(-2,3,base.shape),0,255).astype(np.uint8)
gray=np.tile((np.arange(W)//8).astype(np.uint8)[None,:,None],(H,1,3))
inputs=[base,noisy,dim,dim_noisy,gray]
references=[enhance(a) for a in inputs]
events=work/'quality_events.vec';expected=work/'quality_expected.vec';capture=work/'quality_rtl.hex'
with events.open('w') as ev,expected.open('w') as ex:
    def emit(rst=1,v=0,u=0,l=0,m=7,d=0):ev.write(f'{rst:x} {v:x} {u:x} {l:x} {m:x} 1 {d:024x}\n')
    emit(rst=0);emit(rst=0)
    for mode,image,ref in [(1,a,b) for a,b in zip(inputs,references)]+[(0,gray,natural(gray))]:
        emit(u=1,m=mode);emit();source=image.reshape(-1,3);target=ref.reshape(-1,3)
        for y in range(H):
            for x in range(0,W,4):
                i=y*W+x;emit(v=1,l=int(x==W-4),d=int.from_bytes(source[i:i+4].tobytes(),'big'))
                ex.write(f'{mode} {int(x==W-4):x} {int.from_bytes(target[i:i+4].tobytes(),"big"):024x}\n')
            for _ in range(40):emit()
        for _ in range(1400):emit()
top='style_quality_tb';bench=V/(top+'.sv')
bench.write_text((V/'two_modes_tb.sv').read_text().replace('module two_modes_tb;','module '+top+';'),encoding='utf-8')
files=[R/'enhance_extension'/n for n in ('enhance_core.v','enhance_window.v','enhance_lut.v','enhance_frame_select.v','cartoon_packer.v')]+[bench]
iv=shutil.which('iverilog') or 'C:/Users/18490/Documents/Codex/2026-10-16/new-chat-2/work/tools/icarus12/app/bin/iverilog.exe'
t=time.time();log=compile_and_run(R,iv,top,files,{'W':W,'H':H},[f'+VECTORS={events}',f'+EXPECTED={expected}',f'+CAPTURE={capture}'])
raw=bytes.fromhex(capture.read_text());assert raw==b''.join(a.tobytes() for a in references)
actual=np.frombuffer(raw,np.uint8).reshape(5,H,W,3)
samples=[];noise=[]
def jitter(a):
    a=a.astype(np.float64)
    return float((np.abs(a[:,1:]-a[:,:-1]).mean()+np.abs(a[1:]-a[:-1]).mean())/2)
for i,c in enumerate(colors):
    cy=i//4*40+20;cx=i%4*64+32
    out=actual[0,cy,cx].astype(np.int32);dark=actual[2,cy,cx].astype(np.int32)
    if max(c)==min(c):
        assert out[0]==out[1]==out[2] and dark[0]==dark[1]==dark[2],(c,out,dark)
    else:
        assert np.argmax(out) in np.flatnonzero(np.array(c)==max(c)),(c,out)
        assert np.argmin(out) in np.flatnonzero(np.array(c)==min(c)),(c,out)
        assert np.argmax(dark) in np.flatnonzero(dim[cy,cx]==dim[cy,cx].max()),(c,dark)
        sat0=(max(c)-min(c))/max(c);sat1=(int(out.max())-int(out.min()))/int(out.max())
        assert sat1>=sat0-.025,(c,out,sat0,sat1)
    if min(c)>0:assert dark.min()>0,(c,dark)
    samples.append({'input':c,'output':out.tolist(),'input_at_one_eighth':dim[cy,cx].tolist(),'output_at_one_eighth':dark.tolist()})
    ys=slice(cy-8,cy+8);xs=slice(cx-12,cx+12)
    a=jitter(noisy[ys,xs]);b=jitter(actual[1,ys,xs]);d=jitter(dim_noisy[ys,xs]);e=jitter(actual[3,ys,xs])
    if i not in (9,10):assert b<a and e<d,(i,a,b,d,e)
    noise.append({'patch':i,'input_neighbor_jitter':a,'output_neighbor_jitter':b,'dim_input_neighbor_jitter':d,'dim_output_neighbor_jitter':e})
assert np.all(actual[0,96:104,88:104]==255) and np.all(actual[0,96:104,152:168]==0)
ramp=actual[4,H//2,4::8,0].astype(np.int32)
assert ramp[0]==0 and np.all(ramp[1:]>0) and np.all(np.diff(ramp)>0),ramp.tolist()
nat=natural(gray)[H//2,4::8,0].astype(np.int32)
assert nat[0]==0 and np.all(nat[1:]>0) and np.all(np.diff(nat)>0),nat.tolist()
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
board=Image.new('RGB',(W*3,H*2+72),'#202020');draw=ImageDraw.Draw(board)
for i,(im,label) in enumerate(((base,'正常亮度输入'),(actual[0],'本版实际 RTL'),(actual[1],'带噪声输入的 RTL'),(dim,'1/8 亮度输入'),(actual[2],'弱光输入的 RTL'),(actual[3],'弱光加噪声的 RTL'))):
    x=i%3*W;y=i//3*(H+36);board.paste(Image.fromarray(im),(x,y+36));draw.text((x+8,y+8),label,font=font,fill='white')
board.save(R/'preview/quality_exposure_rtl.png')
log+='PASS all 32 dark gray codes remain distinct in both modes; neutrals and white/black endpoints; all hue families retain channel order; spatial neighbor noise decreases on 14 gray/color/skin patches at normal and 1/8 brightness\n'
result={'test':'shadow_color_noise_quality','log':log,'seconds':round(time.time()-t,2),'pixels':6*W*H,'rgb_bytes_match_reference':True,'hue_and_skin_samples':samples,'dark_gray_input':list(range(32)),'dark_gray_style_output':ramp.tolist(),'dark_gray_natural_output':nat.tolist(),'patch_noise':noise,'noise_seed':90210,'output_sha256':hashlib.sha256(raw).hexdigest(),'source_sha256':{p.relative_to(R).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files+[V/'enhance_model.py',Path(__file__)]}}
(R/'evidence/quality_result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(log,flush=True)
