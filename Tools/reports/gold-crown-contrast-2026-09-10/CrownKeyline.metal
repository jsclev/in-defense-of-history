#include <SwiftUI/SwiftUI_Metal.h>

// Symmetric contour: no directional offset, bevel, lighting or drop shadow.
[[ stitchable ]] half4 crownKeyline(float2 position, SwiftUI::Layer layer,
                                  float radius, half4 ink) {
    half4 face = layer.sample(position);
    half coverage = face.a;
    for (int ring = 1; ring <= 2; ++ring) {
        float r = radius * float(ring) / 2.0;
        for (int i = 0; i < 24; ++i) {
            float theta = float(i) * 6.28318530718 / 24.0;
            coverage = max(coverage, layer.sample(position + r * float2(cos(theta), sin(theta))).a);
        }
    }
    return face + ink * coverage * (1.0h - face.a);
}
