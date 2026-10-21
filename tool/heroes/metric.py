import numpy as np,sys
from PIL import Image
from scipy import ndimage as ndi
def m(p):
    im=np.asarray(Image.open(p).convert('RGBA')).astype(float)
    a=im[...,3]>128; lum=im[...,:3].mean(2)
    ring=a & ~ndi.binary_erosion(a,iterations=4)
    inner=ndi.binary_erosion(a,iterations=10)
    sat=(im[...,:3].max(2)-im[...,:3].min(2))
    # interior dark thin lines: pixels much darker than 7px local median
    med=ndi.median_filter(lum,7)
    lines=inner&(lum<med-40)
    return dict(ring=round(lum[ring].mean()),inner=round(lum[inner].mean()),ringdark=round((lum[ring]<50).mean(),2),sat=round(sat[inner].mean()),lines=round(lines.mean()*100,2))
if __name__ == "__main__":
    for p in sys.argv[1:]: print(p,m(p))
