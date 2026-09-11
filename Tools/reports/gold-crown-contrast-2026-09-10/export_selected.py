"""Crop and export the selected native-rendered crown, preserving its scale/anchor."""
from pathlib import Path
from PIL import Image
import hashlib,importlib.util,json,math,shutil
ROOT=Path('/Users/john/projects/td');DATA=ROOT/'in-defense-of-history-data'
REPORT=Path(__file__).resolve().parent
ART=DATA/'Images/Path-Exit-Crown-Proposals/2026-09-10-outlined'
ART.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('lab',DATA/'ArtReadability/build_readability_lab.py')
lab=importlib.util.module_from_spec(spec);spec.loader.exec_module(lab)
source=REPORT/'device-documents/outline-bold@6x.png'
im=Image.open(source).convert('RGBA');box=im.getchannel('A').getbbox()
assert box and im.size==(1152,1152)
# The standalone image is exactly cropped to all nonzero-alpha pixels.
cropped=im.crop(box);cropped.save(ART/'crown-path-marker.png')
assert cropped.getchannel('A').getbbox()==(0,0,cropped.width,cropped.height)
lab.resize_rgba(cropped,(round(cropped.width*160/cropped.height),160)).save(ART/'crown-path-marker-preview.png')
# Align the catalog crop to whole source points so all density exports share
# one logical canvas; this adds less than 1 source point of transparent margin.
aligned=tuple(math.floor(v/6) if i<2 else math.ceil(v/6) for i,v in enumerate(box))
logical=(aligned[2]-aligned[0],aligned[3]-aligned[1])
anchor=(96-aligned[0],96-aligned[1])
offset=(logical[0]/2-anchor[0],logical[1]/2-anchor[1])
canvas=im.crop(tuple(v*6 for v in aligned))
CATALOG=DATA/'LibertyLineAssets.xcassets/path_exit_crown.imageset'
backup=ART/'previous-catalog';backup.mkdir(exist_ok=True)
exports=[]
for den in (1,2,3):
 name='path_exit_crown'+('' if den==1 else f'@{den}x')+'.png'
 target=CATALOG/name
 if not (backup/name).exists():shutil.copy2(target,backup/name)
 lab.resize_rgba(canvas,(logical[0]*den,logical[1]*den)).save(target)
 exports.append({'path':str(target),'dimensions':[logical[0]*den,logical[1]*den], 'sha256':lab.digest(target)})
record={'selectedOutlinePointsAtMinimum':1.25,'source':str(source),'source_sha256':lab.digest(source),
 'standalone_crop_pixels':box,'standalone_dimensions':cropped.size,'standalone_sha256':lab.digest(ART/'crown-path-marker.png'),
 'catalog_crop_source_points':aligned,'catalog_logical_size':logical,'authored_anchor_in_crop':anchor,
 'crop_center_offset_from_authored_anchor':offset,'calibration_side':96,'minimum_calibration_points':25.6,
 'minimum_image_box_points':[n*25.6/96 for n in logical], 'exports':exports,
 'transparency':'All nonzero-alpha pixels retained. Exact crop for standalone; whole-source-point crop for density consistency.'}
(ART/'crop-and-export.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record,indent=2))
