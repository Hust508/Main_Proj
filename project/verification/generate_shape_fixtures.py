"""Independent test inputs: perspective-projected 3-D cubes and sphere silhouettes.
These are simulation fixtures, not camera measurements or calibrated accuracy data.
"""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw
W,H=1024,600
root=Path(__file__).resolve().parent/'fixtures';root.mkdir(exist_ok=True)
def hull(pts):
 pts=sorted(set(pts))
 def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
 lo=[];hi=[]
 for p in pts:
  while len(lo)>=2 and cross(lo[-2],lo[-1],p)<=0:lo.pop()
  lo.append(p)
 for p in reversed(pts):
  while len(hi)>=2 and cross(hi[-2],hi[-1],p)<=0:hi.pop()
  hi.append(p)
 return lo[:-1]+hi[:-1]
def cube(yaw=0,pitch=0,roll=0,center=(0,0,8),f=600):
 a,b,c=map(math.radians,(yaw,pitch,roll));pts=[]
 for x in [-1,1]:
  for y in [-1,1]:
   for z in [-1,1]:
    x1=x*math.cos(a)+z*math.sin(a);z1=-x*math.sin(a)+z*math.cos(a)
    y1=y*math.cos(b)-z1*math.sin(b);z2=y*math.sin(b)+z1*math.cos(b)
    x2=x1*math.cos(c)-y1*math.sin(c);y2=x1*math.sin(c)+y1*math.cos(c)
    zz=z2+center[2];pts.append((512+f*(x2+center[0])/zz,300+f*(y2+center[1])/zz))
 return hull(pts)
def blank():return Image.new('1',(W,H))
cases=[]
def ellipse(name,box,expected=1,color=0,hole=False):
 im=blank();d=ImageDraw.Draw(im);d.ellipse(box,fill=1)
 if hole:
  l,t,r,b=box;d.ellipse((l+(r-l)*.25,t+(b-t)*.18,l+(r-l)*.44,t+(b-t)*.36),fill=0)
 cases.append(dict(name=name,shape=expected,color=color,image=im))
def polygon(name,points,expected=2):
 im=blank();ImageDraw.Draw(im).polygon(points,fill=1);cases.append(dict(name=name,shape=expected,color=0,image=im,vertices=points))
ellipse('sphere_center',(424,212,599,387))
ellipse('sphere_specular_highlight',(424,212,599,387),hole=True)
ellipse('sphere_shadow',(650,280,817,447),color=1)
ellipse('sphere_off_axis',(240,140,423,311))
ellipse('sphere_64px',(700,180,763,243))
polygon('cube_front',cube())
polygon('cube_yaw_25',cube(25,0,0))
polygon('cube_yaw35_pitch22',cube(35,22,0))
polygon('cube_yaw45_pitch30_roll20',cube(45,30,20))
polygon('cube_yaw15_pitch40_roll65',cube(15,40,65))
polygon('cube_perspective',cube(30,20,10,(.8,-.3,5.5),450))
polygon('cube_front_roll45',cube(0,0,45))
polygon('triangle_up',[(440,390),(600,390),(520,220)],0)
polygon('triangle_right',[(440,220),(620,305),(440,390)],0)
polygon('triangle_rotated',[(460,210),(620,340),(410,390)],0)
ellipse('elongated_ellipse',(350,250,609,339),0)
polygon('too_small_cube',[(300,250),(323,250),(323,273),(300,273)],0)
ellipse('clipped_sphere',(-50,200,109,359),0)
ellipse('green_sphere',(424,212,599,387),0,color=2)
ellipse('blue_sphere',(424,212,599,387),0,color=3)
polygon('octagon',[(512+90*math.cos(math.pi/8+i*math.pi/4),300+90*math.sin(math.pi/8+i*math.pi/4)) for i in range(8)],0)
im=blank();d=ImageDraw.Draw(im);d.rectangle((300,220,369,379),fill=1);d.rectangle((500,220,569,379),fill=1)
cases.append(dict(name='two_disjoint_objects',shape=0,color=0,image=im))
cases.append(dict(name='empty',shape=0,color=0,image=blank()))
metadata=[];report=[]
for i,case in enumerate(cases):
 im=case.pop('image');px=im.load();rowbits=[];qualified=[];red=case['color'] not in [2,3]
 for y in range(H):
  bits=0;start=None
  for x in range(W):
   hit=bool(px[x,y]);bits=(bits<<1)|hit
   if hit and start is None:start=x
   if start is not None and (not hit or x==W-1):
    end=x if hit else x-1
    if red and end-start+1>=4:qualified.append((start,end,y))
    start=None
  rowbits.append(f'{bits:0256x}')
 (root/f'{i:02d}.hex').write_text('\n'.join(rowbits)+'\n',encoding='ascii')
 if qualified:
  l=min(a for a,b,y in qualified);r=max(b for a,b,y in qualified);t=min(y for a,b,y in qualified);b=max(y for a,b,y in qualified)
  found=sum(r-l+1 for l,r,y in qualified)>=200 and r-l+1>=12 and b-t+1>=12
 else:l=r=t=b=0;found=False
 cx=(l+r)//2;cy=(t+b)//2
 value=case['shape']|int(found)<<2|l<<3|r<<14|t<<25|b<<36|cx<<47|cy<<58|case['color']<<69
 metadata.append(f'{value:024x}')
 report.append(dict(index=i,**case,found=found,bbox=[l,r,t,b],center=[cx,cy]))
(root/'metadata.hex').write_text('\n'.join(metadata)+'\n',encoding='ascii')
(root/'cases.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Generated',len(cases),'independent fixtures, projected cube vertices and expected labels/bboxes')
