#!/usr/bin/env python3
"""Blob-based sheet cutter: finds figures on a magenta sheet, orders them in
reading order (rows by y, then x) and saves them as trimmed transparent PNGs.
usage: cut2.py sheet out_dir names...   ('-' skips a figure)"""
import sys, os, numpy as np
from PIL import Image
from scipy import ndimage
src,out=sys.argv[1],sys.argv[2]; names=sys.argv[3:]
os.makedirs(out,exist_ok=True)
a=np.asarray(Image.open(src).convert('RGB')).astype(np.float32)
H,W=a.shape[:2]
mag=np.minimum(a[...,0],a[...,2])-a[...,1]
alpha=np.clip((140-mag)/60.0,0,1)
fg=alpha>0.5
d=ndimage.binary_dilation(fg,iterations=int(os.environ.get("DIL","10")))
lab,n=ndimage.label(d)
objs=ndimage.find_objects(lab)
sizes=ndimage.sum(fg,lab,range(1,n+1))
cand=[]
for i,s in enumerate(objs):
    h=s[0].stop-s[0].start; w=s[1].stop-s[1].start
    if h>0.6*H or w>0.6*W: continue   # frame or border
    cand.append(i)
big=max(sizes[i] for i in cand)
figs=[i for i in cand if sizes[i]>=0.12*big]
cy={i:(objs[i][0].start+objs[i][0].stop)/2 for i in figs}
cx={i:(objs[i][1].start+objs[i][1].stop)/2 for i in figs}
figs.sort(key=lambda i:cy[i])
rows=[];cur=[]
for i in figs:
    if cur and cy[i]-np.mean([cy[j] for j in cur])>0.09*H:
        rows.append(cur);cur=[]
    cur.append(i)
rows.append(cur)
order=[i for r in rows for i in sorted(r,key=lambda j:cx[j])]
print('rows',[len(r) for r in rows],'figs',len(order))
for name,i in zip(names,order):
    if name=='-': continue
    keep=(lab==i+1)&fg
    keep=ndimage.binary_dilation(keep,iterations=2)
    al=alpha*keep
    rgb=a.copy(); edge=(al>0)&(al<1)
    m=np.minimum(rgb[...,0],rgb[...,2]); spill=np.clip(m-rgb[...,1],0,None)*edge
    rgb[...,0]-=spill*0.8; rgb[...,2]-=spill*0.8
    rgba=np.dstack([np.clip(rgb,0,255),al*255]).astype(np.uint8)
    ys,xs=np.where(al>0.05)
    crop=Image.fromarray(rgba,'RGBA').crop((xs.min(),ys.min(),xs.max()+1,ys.max()+1))
    side=320 if name.startswith('b_') else (128 if name.startswith('i_') else 256)
    crop.thumbnail((side,side),Image.LANCZOS)
    crop.save(os.path.join(out,name+'.png')); print(name,crop.size)
