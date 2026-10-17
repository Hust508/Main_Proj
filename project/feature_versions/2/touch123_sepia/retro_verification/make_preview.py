from pathlib import Path
import sys,argparse
from PIL import Image,ImageOps,ImageDraw,ImageFont
import numpy as np
from sepia_model import advance
HERE=Path(__file__).resolve().parent; ROOT=HERE.parent

def make(source):
    w,h=1280,720
    image=ImageOps.contain(Image.open(source).convert('RGB'),(w,h))
    canvas=Image.new('RGB',(w,h),'white');canvas.paste(image,((w-image.width)//2,(h-image.height)//2))
    rgb=np.asarray(canvas).astype(np.int32)
    y=(77*rgb[:,:,0]+150*rgb[:,:,1]+29*rgb[:,:,2]+128)//256
    values=np.arange(256)/255
    tone=8+239*np.power(values,.94)
    table=np.stack([np.clip(np.rint(a*tone+b),0,255) for a,b in ((1.04,5),(.94,1),(.76,-2))],axis=1).astype(np.int32)
    qx=abs(np.arange(w)-w//2)//32;qy=abs(np.arange(h)-h//2)//16
    penalty_x=(qx*qx+8)//16;penalty_y=((qy*qy+8)//16)//2
    gain=256-penalty_y[:,None]-penalty_x[None,:]
    r=0x1ace^1
    noise=np.empty(w*h,dtype=np.int32)
    for i in range(w*h):
        r=advance(r);noise[i]=(-1,0,0,1)[(r>>6)&3]
    out=np.clip((table[y]*gain[:,:,None]+128)//256+noise.reshape(h,w,1),0,255).astype(np.uint8)
    sepia=Image.fromarray(out)
    canvas.save(ROOT/'preview/original_720p.png');sepia.save(ROOT/'preview/sepia_720p.png')
    sepia.crop((128,60,1152,660)).save(ROOT/'preview/sepia_dsi_crop.png')
    original_crop=canvas.crop((128,60,1152,660))
    width,height=768,450
    board=Image.new('RGB',(width*2,height+44),'#202020')
    board.paste(original_crop.resize((width,height)),(0,44))
    board.paste(sepia.crop((128,60,1152,660)).resize((width,height)),(width,44))
    fontpath=Path('C:/Windows/Fonts/msyh.ttc')
    font=ImageFont.truetype(str(fontpath),22) if fontpath.exists() else ImageFont.load_default()
    draw=ImageDraw.Draw(board);draw.text((20,8),'原图',fill='white',font=font)
    draw.text((width+20,8),'棕褐老照片 · 本版算法参考效果',fill='white',font=font)
    board.save(ROOT/'preview/portrait_comparison.png')
    return canvas

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('source');args=ap.parse_args()
    make(args.source)
    print(ROOT/'preview/portrait_comparison.png')
