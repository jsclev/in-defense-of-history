import SwiftUI

public struct DebugLayoutGuidesView: View {
    @State private var screen: ScreenGeometry?
    private let canvasSpec: CanvasSpec
    
    @State private var hardwareInsets: UIEdgeInsets = .zero
    
    private let safeDash: [CGFloat] = [12, 8]
    private let playableDash: [CGFloat] = [4, 10]

    private let labelFloor: CGFloat = 30
    
    private let physicalLineThickness: Int = 4
    private let safeInsetsLineThickness: Int = 16
    private let playAreaLineThickness: Int = 16

    private let physicalGuideColor = Color(red: 1.0, green: 0.16, blue: 0.16)
    private let playAreaGuideColor = Color(red: 0.75, green: 0.15, blue: 1.0)
    private let safeInsetsGuideColor = Color(red: 0.18, green: 1.0, blue: 0.33)
    
    @State private var physicalRectWidth: CGFloat?
    @State private var physicalRectHeight: CGFloat?

    @State private var safeInsetsRect: CGRect?
//    private var insets: EdgeInsets {
//        EdgeInsets(top: screen.safe.minY,
//                   leading: screen.safe.minX,
//                   bottom: screen.safe.maxY,
//                   trailing: screen.safe.maxX)
//    }
    
    public init(canvasSpec: CanvasSpec) {
//        self.screen = screen
        self.canvasSpec = canvasSpec
        
//        self.physicalRectWidth = screen.physical.width
//        self.physicalRectHeight = screen.physical.height
//        self.safeInsetsRect = screen.safe
    }

    public var body: some View {
        GeometryReader { geometry in
            let globalFrame = geometry.frame(in: .global)
            let strokeWidth: CGFloat = 1 // Or 1
//            let rectHeight: CGFloat = 300
//            let rectWidth: CGFloat = 300
            let rectHeight: CGFloat = globalFrame.height
            let rectWidth: CGFloat = globalFrame.width
            
            ZStack(alignment: .topLeading) {
                // Your background filling the full screen
                Color.black.ignoresSafeArea()
                
                Rectangle()
                    .strokeBorder(Color.red, lineWidth: strokeWidth)
                    .frame(width: rectWidth, height: rectHeight)
                    .position(
                        x: globalFrame.midX,
                        // Calculate from the literal physical top of the screen window
                        y: globalFrame.minY + (rectHeight / 2) + (strokeWidth / 2)
                    )
            }
        }
        .ignoresSafeArea()
//        ZStack(alignment: .topLeading) {
//            Rectangle()
//                .strokeBorder(Color(red: 1.0, green: 0.16, blue: 0.16),
//                              style: StrokeStyle(lineWidth: CGFloat(1)))
//                .frame(width: 300.0, height: 300.0)
//                .position(x: 300.0, y: 00.0)
//                .offset(y: 0.5)
//        }
//        .ignoresSafeArea()
//        .onAppear {
//            self.hardwareInsets = currentHardwareInsets
//            
////            hardwareInsets = {
////                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
////                      let mainWindow = windowScene.windows.first else {
////                    return UIEdgeInsets()
////                }
////                return mainWindow.safeAreaInsets
////            }()
//            
//            var physicalScreen: CGRect {
//                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
//                    // Fallback to standard UIScreen bounds if the window scene is still initializing
//                    return UIScreen.main.bounds
//                }
//                return windowScene.screen.bounds
//            }
//            
//            safeInsetsRect = CGRect(
//                x: physicalScreen.origin.x + hardwareInsets.left,
//                y: physicalScreen.origin.y + hardwareInsets.top,
//                width: physicalScreen.size.width - (hardwareInsets.left + hardwareInsets.right),
//                height: physicalScreen.size.height - (hardwareInsets.top + hardwareInsets.bottom)
//            )
//            
//            screen = ScreenGeometry(physicalRect: physicalScreen,
//                                                safeInsetsRect: safeInsetsRect!,
//                                                canvasSpec: canvasSpec)
//            
//            physicalRectWidth = screen!.physical.width
//            physicalRectHeight = screen!.physical.height
//            
//            // Debug check to verify your numbers are back
//        }
//            createRectView(rect: screen.physical,
//                           borderColor: physicalGuideColor,
//                           borderThickness: physicalLineThickness)
//            createRectView(rect: safeInsetsRect,
//                           borderColor: safeInsetsGuideColor,
//                           borderThickness: safeInsetsLineThickness,
//                           borderDash: safeDash)
//            createPlayAreaView()

//            inset("L \(fmt(insets.leading))",
//                  at: CGPoint(x: max(insets.leading / 2, labelFloor),
//                              y: safeInsetsRect.midY))
//            inset("R \(fmt(insets.trailing))",
//                  at: CGPoint(x: min(physicalRectWidth - insets.trailing / 2,
//                                     physicalRectWidth - labelFloor),
//                              y: safeInsetsRect.midY))
//            inset("T \(fmt(insets.top))",
//                  at: CGPoint(x: safeInsetsRect.midX,
//                              y: max(insets.top / 2, labelFloor)))
//            inset("B \(fmt(insets.bottom))",
//                  at: CGPoint(x: safeInsetsRect.midX,
//                              y: min(physicalRectHeight - insets.bottom / 2,
//                                     physicalRectHeight - labelFloor)))

//            readout
//                .position(x: physicalRectWidth / 2, y: physicalRectHeight * 0.62)
//        }
//        .frame(width: physicalRectWidth, height: physicalRectHeight, alignment: .topLeading)
//        .allowsHitTesting(false)
    }

    private func createRectView(rect: CGRect,
                                borderColor: Color,
                                borderThickness: Int,
                                borderDash: [CGFloat] = []) -> some View {
        // Ensure that the border thickness is an even number,
        // so that all our guides will show up cleanly on the screen
        assert(borderThickness.isMultiple(of: 2))
        
//        let origin = CGPoint(x: Double(rect.minX - CGFloat(borderThickness / 2)),
//                             y: Double(rect.minY - CGFloat(borderThickness / 2)))
//        let size = CGSize(width: rect.width + Double(2 * borderThickness),
//                          height: rect.height + Double(2 * borderThickness))
        let origin = CGPoint(x: rect.minX,
                             y: rect.minY)
        let size = CGSize(width: rect.width,
                          height: rect.height)
        let modifiedRect = CGRect(origin: origin, size: size)
        
        return Rectangle()
            .strokeBorder(borderColor,
                          style: StrokeStyle(lineWidth: CGFloat(borderThickness), dash: borderDash))
            .frame(width: modifiedRect.width, height: modifiedRect.height)
//            .offset(x: modifiedRect.minX, y: modifiedRect.minY)
    }

    private func createPlayAreaView() -> some View {
        let projection = LevelMapArt.projection(canvasSpec: canvasSpec, fitting: screen!.playable)
        return SwiftUI.Path(canvasSpec.playAreaShape)
            .applying(projection.viewTransform)
            .stroke(playAreaGuideColor,
                    style: StrokeStyle(lineWidth: CGFloat(playAreaLineThickness),
                                       dash: playableDash))
    }

    private func fmt(_ v: CGFloat) -> String { String(format: "%.0f", v) }

    private func fmt(_ r: CGRect) -> String {
        "(\(fmt(r.minX)), \(fmt(r.minY)))  \(fmt(r.width)) × \(fmt(r.height))"
    }

    /// The measured values themselves, so "is the math right" can be read
    /// straight off the device.
//    private var readout: some View {
//        VStack(alignment: .leading, spacing: 3) {
//            Text("physical  \(fmt(screen.physical))").foregroundStyle(physicalGuideColor)
//            Text("safe      \(fmt(safeInsetsRect))").foregroundStyle(safeInsetsGuideColor)
//            Text("insets    L \(fmt(insets.leading))  R \(fmt(insets.trailing))  T \(fmt(insets.top))  B \(fmt(insets.bottom))")
//                .foregroundStyle(safeInsetsGuideColor)
//            Text("playable  \(fmt(screen.playable))").foregroundStyle(playAreaGuideColor)
//        }
//        .font(.system(size: Typography.size(13), weight: .bold, design: .monospaced))
//        .padding(.horizontal, 10)
//        .padding(.vertical, 6)
//        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
//    }

    private func inset(_ text: String, at point: CGPoint) -> some View {
        Text(text)
            .font(.system(size: Typography.size(11), weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(safeInsetsGuideColor.opacity(0.9),
                        in: RoundedRectangle(cornerRadius: 3))
            .position(point)
    }
}
