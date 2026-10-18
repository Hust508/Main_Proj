"""Independent image-space oracles. Generated files stay in sim_work/."""
from pathlib import Path
import json
import numpy as np
from reference.enhance_model import enhance, neighborhoods
from reference.sepia_model import advance, sepia

def effect(a, mode, frame):
    v=a.astype(np.int32)
    if mode==0:return a
    if mode==1:
        y=(77*v[:,:,0]+150*v[:,:,1]+29*v[:,:,2]+128)//256
        return np.repeat(y[:,:,None],3,2).astype(np.uint8)
    if mode==3:return 255-a
    if mode==4:
        s=a[::8,::8].astype(np.int32)
        r=s[:,:,0]>>5;g=s[:,:,1]>>5;b=s[:,:,2]>>6
        s=np.stack(((r<<5)|(r<<2)|(r>>1),(g<<5)|(g<<2)|(g>>1),b*85),2)
        return np.repeat(np.repeat(s,8,0),8,1)[:a.shape[0],:a.shape[1]].astype(np.uint8)
    if mode==6:
        h,w=a.shape[:2];rng=0x1ace^((frame<<1)|1);out=np.empty_like(a)
        for y in range(h):
            for x in range(w):
                rng=advance(rng);r,g,b=map(int,a[y,x])
                c=sepia((r<<16)|(g<<8)|b,x,y,rng,w,h)
                out[y,x]=(c>>16,(c>>8)&255,c&255)
        return out
    if mode==7:return enhance(a)
    r,g,b=v[:,:,0],v[:,:,1],v[:,:,2]
    co=r-b;t=b+co//2;cg=g-t;y=t+cg//2
    n=neighborhoods(y)
    mag=np.abs(n[2]+2*n[5]+n[8]-n[0]-2*n[3]-n[6])+np.abs(n[6]+2*n[7]+n[8]-n[0]-2*n[1]-n[2])
    if mode==5:return np.repeat(np.where(mag>=80,255,0)[:,:,None],3,2).astype(np.uint8)
    poster=(v>>6)*85
    return np.where((mag>=80)[:,:,None],np.array([16,24,32]),poster).astype(np.uint8)

def save(prefix,w,h,modes):
    rng=np.random.RandomState(508);src=[];expected=[]
    yy,xx=np.mgrid[:h,:w]
    for f,m in enumerate(modes):
        # Color ramps, hard borders, neutral shadows, all colors and noise.
        a=np.stack(((xx*9+yy*3)%256,(xx*3+yy*11)%256,(xx*7+yy*5)%256),2).astype(np.uint8)
        a[:h//3]=rng.randint(0,256,(h//3,w,3)).astype(np.uint8)
        a[h//3:2*h//3,:w//2]=np.repeat(((xx[h//3:2*h//3,:w//2]%32))[:,:,None],3,2)
        a[-2:]=np.array([250,80,20]);a[-1,-4:]=np.array([20,80,250])
        src.append(a);expected.append(effect(a,m,f))
    out=Path(__file__).absolute().parent/'sim_work';out.mkdir(exist_ok=True)
    for name,frames in [('input',src),('expected',expected)]:
        with (out/(prefix+'_'+name+'.hex')).open('w') as stream:
            for frame in frames:
                for beat in frame.reshape(-1,12):stream.write(bytes(beat).hex()+'\n')
    with (out/(prefix+'_packed.hex')).open('w') as stream:
        for frame in expected:
            for word in frame.reshape(-1,16):stream.write(bytes(word).hex()+'\n')
    print('Generated',prefix,w,h,'modes',modes,'pixels',w*h*len(modes))

if __name__=='__main__':
    save('filters',64,24,[0,1,2,3,4,5,6,7,7,6,5,4,3,2,1,0])
    save('filters720',1280,720,[6,7])
    save('transport',64,24,[6,7,0,5])
