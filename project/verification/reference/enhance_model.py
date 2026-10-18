"""Shadow-preserving spatial style: gentle palette, common RGB lift, bounded saturation."""
import numpy as np

def neighborhoods(a):
    q=np.pad(a,1,mode='edge')
    return [q[y:y+a.shape[0],x:x+a.shape[1]] for y in range(3) for x in range(3)]

def enhance(rgb, stages=False):
    v=np.asarray(rgb,dtype=np.int32);r,g,b=v[:,:,0],v[:,:,1],v[:,:,2]
    co=r-b;t=b+co//2;cg=g-t;y=t+cg//2
    weights=(1,2,1,2,4,2,1,2,1)
    sums=[np.zeros(y.shape,np.int32) for _ in range(3)]
    for yn,cn,gn,w in zip(neighborhoods(y),neighborhoods(co),neighborhoods(cg),weights):
        keep=(np.abs(yn-y)<=40)&(np.abs(cn-co)<=64)&(np.abs(gn-cg)<=64)
        for acc,n,c in zip(sums,(yn,cn,gn),(y,co,cg)):acc+=w*np.where(keep,n,c)
    y,co,cg=[(a+8)//16 for a in sums]
    a=neighborhoods(y)
    gx=a[2]+2*a[5]+a[8]-a[0]-2*a[3]-a[6];gy=a[6]+2*a[7]+a[8]-a[0]-2*a[1]-a[2]
    magnitude=np.abs(gx)+np.abs(gy)
    smooth=[]
    for c in (y,co,cg):
        blur=(sum(w*n for w,n in zip(weights,neighborhoods(c)))+8)//16
        smooth.append(np.where(magnitude>=384,c,np.where(magnitude>=192,(c+blur+1)//2,blur)))
    y,co,cg=smooth
    # Preserve all dark codes; use a finer palette only above Y=31.
    y=np.where(y<32,y,np.minimum(255,((y+4)//8)*8))
    co=np.where(y<32,co,((co+2)//4)*4);cg=np.where(y<32,cg,((cg+2)//4)*4)
    t=y-cg//2;g=cg+t;b=t-co//2;r=b+co
    color=np.clip(np.stack((r,g,b),2),0,255)
    maxc=color.max(2)
    gain=np.array([640 if i==0 else min(640,round(256*(255/i)**.2)) for i in range(256)],np.int32)
    color=np.minimum(255,(color*gain[maxc][:,:,None]+128)//256)
    color=np.maximum(0,color-(color.max(2)[:,:,None]-color+2)//4)
    level=np.where(magnitude>=256,3,np.where(magnitude>=128,2,np.where(magnitude>=64,1,0)))
    out=np.where(level[:,:,None]==3,7*color//8,np.where(level[:,:,None]==2,15*color//16,np.where(level[:,:,None]==1,31*color//32,color))).astype(np.uint8)
    if stages:return out,color.astype(np.uint8),np.clip(magnitude,0,255).astype(np.uint8)
    return out

def natural(rgb):
    """Mild natural color calibration; no spatial filtering or quantization."""
    v=np.asarray(rgb,dtype=np.int32);r,g,b=v[:,:,0],v[:,:,1],v[:,:,2]
    co=r-b;t=b+co//2;cg=g-t;y=t+cg//2
    lut=np.rint(255*(np.arange(256)/255.0)**0.95).astype(np.int32)
    y=lut[y];co=(9*co+4)//8;cg=(9*cg+4)//8
    t=y-cg//2;g=cg+t;b=t-co//2;r=b+co
    return np.clip(np.stack((r,g,b),axis=2),0,255).astype(np.uint8)
