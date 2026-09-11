// Isolated UIKit origin regression; mode 2 uses production ScreenCanvas and LevelViewport.
import SwiftUI
import UIKit

@MainActor enum Readings {
 static var frames: [String: [CGFloat]] = [:]
 static var phase = "initial"
 static var reports: [[String: Any]] = []
 static func capture(_ window: UIWindow, extra: [String:Any]) {
  var report: [String:Any] = ["phase":phase,"runID":ProcessInfo.processInfo.arguments.last ?? "","window":[window.bounds.width,window.bounds.height],"safeInsets":[window.safeAreaInsets.top,window.safeAreaInsets.left,window.safeAreaInsets.bottom,window.safeAreaInsets.right],"frames":frames]
  report.merge(extra) { _,new in new }
  reports.append(report)
  let data=try! JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys])
  let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("origin-results.json")
  try! data.write(to:url)
  print(String(data:try! JSONSerialization.data(withJSONObject:report,options:.sortedKeys),encoding:.utf8)!)
 }
}
struct Spy: UIViewRepresentable {
 let key: String
 func makeUIView(context:Context)->SpyView { SpyView(key:key) }
 func updateUIView(_ view:SpyView,context:Context) { view.record() }
}
final class SpyView: UIView {
 let key: String
 init(key:String){self.key=key;super.init(frame:.zero);isUserInteractionEnabled=false}
 required init?(coder:NSCoder){fatalError()}
 override func didMoveToWindow(){super.didMoveToWindow();record()}
 override func layoutSubviews(){super.layoutSubviews();record()}
 func record(){if let window {let r=convert(bounds,to:window);Readings.frames[key]=[r.minX,r.minY,r.width,r.height]}}
}
@MainActor final class Delegate: NSObject, UIApplicationDelegate {
 func application(_ app:UIApplication,supportedInterfaceOrientationsFor window:UIWindow?)->UIInterfaceOrientationMask { .landscape }
}
@main struct OriginProbe: App {
 @UIApplicationDelegateAdaptor(Delegate.self) var delegate
 var body:some Scene {WindowGroup{ProbeRoot()}}
}
struct ProbeRoot:View {
 @State private var size:CGSize?
 @State private var bottom:CGFloat=0
 @State private var top:CGFloat=0
 @State private var wave=true
 @State private var mode=0
 var body:some View {
  Group {
   if mode == 2 {
    ScreenCanvas { canvasContent }
   } else {
    ZStack { canvasContent }
   }
  }
  .ignoresSafeArea()
  .statusBarHidden(true)
  .persistentSystemOverlays(.hidden)
  .onAppear {
   let window=(UIApplication.shared.connectedScenes.first as! UIWindowScene).windows.first!
   size=window.bounds.size;top=window.safeAreaInsets.top;bottom=window.safeAreaInsets.bottom
  }
  .task {
   try? await Task.sleep(for:.seconds(2))
   let window=(UIApplication.shared.connectedScenes.first as! UIWindowScene).windows.first!
   for m in [0,1,2] {
    mode=m
    for visible in [true,false,true] {
     wave=visible
     Readings.phase="mode-\(m)-wave-\(visible)"
     try? await Task.sleep(for:.milliseconds(350))
     Readings.capture(window,extra:["measured":[size!.width,size!.height],"measuredTop":top,"measuredBottom":bottom])
    }
   }
  }
 }
 @ViewBuilder private var canvasContent:some View {
  if let size {
   Group {
    if mode == 1 {stage(size).ignoresSafeArea()} else {stage(size)}
   }.background(Spy(key:"stage"))
  }
 }
 func stage(_ size:CGSize)->some View {
  LevelViewport(size:size) {
   ZStack(alignment:.topLeading) {
    Color(red:0.2,green:0.4,blue:0.2)
    Color.red.frame(width:12,height:12).background(Spy(key:"map-marker")).position(x:100,y:100)
   }.background(Spy(key:"map"))
  } interface: {
   ZStack(alignment:.topLeading) {
    VStack {
     HStack {
      Spacer()
      Color.yellow.frame(width:44,height:44).background(Spy(key:"speed"))
      Color.orange.frame(width:44,height:44).background(Spy(key:"pause"))
     }
     Spacer()
    }.padding(.top,top+7).padding(.horizontal,59).padding(.bottom,bottom).background(Spy(key:"hud"))
    if wave {Color.blue.frame(width:44,height:44).position(x:300,y:100).frame(width:size.width,height:size.height,alignment:.topLeading)}
   }
  } presentations: { EmptyView() }
 }
}
