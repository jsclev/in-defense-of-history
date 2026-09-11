"""Check the phone render removes thickness while retaining the warm face."""
from pathlib import Path
from PIL import Image
import json
REPORT=Path(__file__).resolve().parent
source=Image.open(REPORT/'device-documents/compiled-crown.png').convert('RGBA')
face=Image.open(REPORT/'device-documents/flat-face@3x.png').convert('RGBA')
assert source.size==face.size, (source.size, face.size)
pairs=list(zip(source.getdata(),face.getdata()))
def violet(p):
 r,g,b,a=p
 return a>=128 and b>g*1.3 and r-b<51
def warm(p):
 r,g,b,a=p
 return a>=250 and r-b>130
original_violet=sum(violet(p) for p,_ in pairs)
remaining_violet=sum(violet(p) for _,p in pairs)
core=[p for s,p in pairs if warm(s)]
retained=sum(p[3]>=245 for p in core)/len(core)
result={'passed':original_violet>0 and remaining_violet==0 and retained>.99,
 'sourceSize':source.size,'originalVioletPixels':original_violet,
 'remainingVioletPixels':remaining_violet,'warmCoreRetention':retained,
 'outputAlphaExtrema':face.getchannel('A').getextrema()}
(REPORT/'flat-face-checks.json').write_text(json.dumps(result,indent=2)+'\n')
print(result)
assert result['passed']
