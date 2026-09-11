import SwiftUI
import AppKit
@main struct Repro {
 @MainActor static func main() throws {
  for screen in [CGSize(width:852,height:393),CGSize(width:1024,height:768)] {
   for show in [true,false] {
    let stage = ZStack(alignment:.topLeading) {
      ZStack(alignment:.topLeading) {
        Color.black
        Color.green.frame(width:screen.width*1.49,height:screen.height*1.91)
          .position(x:screen.width/2,y:screen.height/2)
        Rectangle().fill(Color.red).frame(width:12,height:12).position(x:100,y:100)
      }
      VStack { Text("HUD"); Spacer(); Text("BOTTOM") }.padding(10)
      if show {
       ZStack(alignment:.topLeading) {
        Circle().fill(Color.yellow).frame(width:44,height:44).position(x:40,y:40)
       }.frame(width:screen.width,height:screen.height,alignment:.topLeading)
      }
    }
    let renderer=ImageRenderer(content:stage.frame(width:screen.width-118,height:screen.height-34))
    renderer.proposedSize=ProposedViewSize(width:screen.width-118,height:screen.height-34)
    let cg=renderer.cgImage!
    let rep=NSBitmapImageRep(cgImage:cg)
    try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"/tmp/td-map-stability/centered-\(Int(screen.width))-\(show).png"))
    print(screen,show,cg.width,cg.height)
   }
  }
 }
}
