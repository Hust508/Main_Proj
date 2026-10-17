"""Integer reference from the documented curve and raster pixel positions."""
import math

def advance(r):
    return ((r<<1)&65535)|(((r>>15)^(r>>13)^(r>>12)^(r>>10))&1)

def sepia(c,x,y,rng,w=1280,h=720,grain=1,vignette=1):
    r,g,b=(c>>16)&255,(c>>8)&255,c&255
    luminance=(77*r+150*g+29*b+128)//256
    tone=8+239*math.pow(luminance/255,0.94)
    rgb=[max(0,min(255,round(a*tone+bias))) for a,bias in ((1.04,5),(.94,1),(.76,-2))]
    if vignette:
        qx=abs(x-w//2)//32; qy=abs(y-h//2)//16
        px=min(60,(qx*qx+8)//16) if qx<31 else 60
        py=(min(60,(qy*qy+8)//16) if qy<31 else 60)//2
        gain=256-px-py
    else: gain=256
    n=(-grain,0,0,grain)[(rng>>6)&3]
    rgb=[max(0,min(255,(v*gain+128)//256+n)) for v in rgb]
    return (rgb[0]<<16)|(rgb[1]<<8)|rgb[2]

def original_edge(pixels,w,h,threshold=80):
    # Independent 2-D Sobel calculation of the supplied original edge design.
    gray=[]
    for y in range(h):
        row=[]
        for x in range(0,w,2):
            a=pixels[y*w+x]; b=pixels[y*w+x+1]
            values=[(c>>18)+((c>>9)&127)+((c>>2)&63) for c in (a,b)]
            row.append(sum(values)//2)
        gray.append(row)
    out=[0]*(w*h)
    for y in range(2,h):
        for x in range(2,w//2):
            a,b,c=gray[y-2][x-2:x+1];d,e,f=gray[y-1][x-2:x+1];g,hh,i=gray[y][x-2:x+1]
            magnitude=abs(c+2*f+i-a-2*d-g)+abs(a+2*b+c-g-2*hh-i)
            value=0xffffff if magnitude>=threshold else 0
            out[y*w+2*x:y*w+2*x+2]=[value,value]
    return out
