import SwiftUI

//extension ScreenGeometry {
//    init(proxy: GeometryProxy, virtualCanvas: VirtualCanvas) {
//        let insets = proxy.safeAreaInsets
//        self.init(
//            fullSize: CGSize(width: proxy.size.width + insets.leading + insets.trailing,
//                             height: proxy.size.height + insets.top + insets.bottom),
//            leading: insets.leading, top: insets.top,
//            trailing: insets.trailing, bottom: insets.bottom,
//            virtualCanvas: virtualCanvas)
//    }
//}

extension View {
    /// Authoritatively pulls the live hardware safe area insets directly from the active rendering window
    var currentHardwareInsets: UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              // Look specifically for the active key window currently displaying content
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return .zero
        }
        return keyWindow.safeAreaInsets
    }
}
//extension View {
//    var authoritativeTopY: CGFloat {
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
//            return 0
//        }
//        
//        // 1. Check the system status bar manager. It tracks the hardware dimension
//        // of the top bar area regardless of whether the software hides it.
//        if let statusBarHeight = windowScene.statusBarManager?.statusBarFrame.height, statusBarHeight > 0 {
//            return statusBarHeight
//        }
//        
//        // 2. If the app launched directly into landscape and hidden mode, the status bar height
//        // might report 0. We fetch the un-wiped coordinate space layer from the root window.
//        if let rootWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
//            // Check the root layout margins which are separate from safe area guides
//            let topMargin = rootWindow.rootViewController?.view.layoutMargins.top ?? 0
//            if topMargin > 0 {
//                return topMargin
//            }
//        }
//        
//        // 3. Absolute Fallback: On modern all-screen iPhones, the hardware safe top 
//        // threshold is physically mapped to a minimum of 20 points to account for the bezel.
//        return 20.0
//    }
//}

/// The one place window geometry is optional: measures the screen on the
/// first frame, then hands the content a plain ScreenGeometry forever after.
/// Geometry cannot exist before the window's first layout, so the optional
/// is irreducible — this view confines it.
//@available(iOS 26.0, *)
//struct ScreenGeometryGate<Content: View>: View {
//    let virtualCanvas: VirtualCanvas
//    @ViewBuilder let content: (ScreenGeometry) -> Content
//
//    @State private var screen: ScreenGeometry?
//    @State private var hardwareInsets: UIEdgeInsets = .zero
//
//
//    var body: some View {
//        if let screen {
//            content(screen)
//        } else {
//            
////            GeometryReader { geometry in
////                // Read the true physical hardware inset directly from the device window
//////                let hardwareInsets: UIEdgeInsets = {
//////                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//////                          let mainWindow = windowScene.windows.first else {
//////                        return UIEdgeInsets()
//////                    }
//////                    return mainWindow.safeAreaInsets
//////                }()
////                
////                var physicalScreen: CGRect {
////                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
////                        // Fallback to standard UIScreen bounds if the window scene is still initializing
////                        return UIScreen.main.bounds
////                    }
////                    return windowScene.screen.bounds
////                }
////                
////                let safeInsetsRect = CGRect(
////                    x: physicalScreen.origin.x + hardwareInsets.left,
////                    y: physicalScreen.origin.y + hardwareInsets.top,
////                    width: physicalScreen.size.width - (hardwareInsets.left + hardwareInsets.right),
////                    height: physicalScreen.size.height - (hardwareInsets.top + hardwareInsets.bottom)
////                )
////                
////                Color.clear
////                    .onAppear {  }
//            }
//            .ignoresSafeArea()
//            .onAppear {
//                // Triggers exactly when the window lifecycle passes the 0-value initialization phase
//                self.hardwareInsets = currentHardwareInsets
//                
//                var physicalScreen: CGRect {
//                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
//                        // Fallback to standard UIScreen bounds if the window scene is still initializing
//                        return UIScreen.main.bounds
//                    }
//                    return windowScene.screen.bounds
//                }
//                
//                screen = ScreenGeometry(physicalRect: physicalScreen,
//                                                    safeInsetsRect: safeInsetsRect,
//                                                    virtualCanvas: virtualCanvas)
//                
//                // Debug check to verify your numbers are back
//                print("Authoritative Top Hardware Inset: \(hardwareInsets.top)")
//            }
//        }
//    }
//}

extension View {
    func hudAnchored(_ corner: HudCorner,
                     margin: CGFloat,
                     size: CGSize = .zero,
                     in geometry: ScreenGeometry) -> some View {
        let frame = HudPlacementSolver.frame(size: size, corner: corner,
                                             margin: margin, in: geometry)
        return self
            .offset(x: frame.minX, y: frame.minY)
            .frame(width: geometry.physical.width, height: geometry.physical.height,
                   alignment: .topLeading)
    }
}

extension View {
    func hudFrame(_ rect: CGRect, in geometry: ScreenGeometry,
                  alignment: Alignment = .center) -> some View {
        self.frame(width: rect.width, height: rect.height, alignment: alignment)
            .offset(x: rect.minX, y: rect.minY)
            .frame(width: geometry.physical.width, height: geometry.physical.height,
                   alignment: .topLeading)
    }
}
