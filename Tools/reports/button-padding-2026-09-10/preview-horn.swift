import SwiftUI
import AppKit
struct CallWaveArtwork: View {
    let side: CGFloat

    private var source: some View {
        Image(nsImage: NSImage(contentsOfFile: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/hud_call_wave.imageset/hud_call_wave@3x.png")!)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: side, height: side)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.75, green: 0.04, blue: 0.015),
                             Color(red: 0.30, green: 0, blue: 0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(side * 0.04)
            source
                .mask(Circle().padding(side * 0.045))
                .scaleEffect(0.90)
            source
                .mask(Circle().strokeBorder(lineWidth: side * 0.055))
        }
        .frame(width: side, height: side)
    }
}

let app = NSApplication.shared
let content = HStack(spacing: 16) {
    Image(nsImage: NSImage(contentsOfFile: "/Users/john/projects/td/in-defense-of-history-data/LibertyLineAssets.xcassets/hud_call_wave.imageset/hud_call_wave@3x.png")!).resizable().scaledToFit().frame(width: 44, height: 44)
    CallWaveArtwork(side: 44)
}.padding(10).background(Color(red: 0.2, green: 0.3, blue: 0.2))
let renderer = ImageRenderer(content: content)
renderer.scale = 1
let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/Users/john/projects/td/in-defense-of-history/Tools/reports/button-padding-2026-09-10/horn-layout-preview@1x.png"))
