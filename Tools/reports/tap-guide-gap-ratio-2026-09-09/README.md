# Cyan guide gap ratio

Changed the cyan pattern to **4.8 points of line and 7.2 points of gap**: 40% cyan coverage and 60% empty space. Previously, 8.092 points of line and 4 points of gap left about 33% empty. The new gap is 1.5 times the dash length.

The game retains its 3-point line thickness and the editor retains its matching 1.5-point guide thickness. Purple remains 7.935 points of line and 10 points of gap. Future requests to shorten the cyan dash refer to reducing its share of the repeating pattern so more purple shows through.

The production debug guide was host-rendered and inspected at phone size. More purple is visible through the expanded cyan gaps. The render is a layout proof, not an on-device gameplay screenshot. No Simulator was used. Build and physical-iPhone deployment logs are retained alongside the proof.

[Phone guide](phone-guides@1x.png)
