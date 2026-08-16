import SwiftUI

struct LevelTowerSlotsView: View {
    let towerSlotImageName = "tower_slot_field"
    
    let debugMode: Bool
    let slotPositions: [CGPoint]
    let size: CGSize
    let projection: LevelMapProjection
    
    var body: some View {
        ForEach(Array(slotPositions.enumerated()), id: \.offset) { index, slotPosition in
            if debugMode {
                ZStack {
                    Image(towerSlotImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: projection.viewLength(size.width),
                               height: projection.viewLength(size.height))
                        .allowsHitTesting(false)
                    
                    Text(String(index))
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.black)
                        .padding()
                }.position(projection.viewPoint(slotPosition))
            }
            else {
                Image(towerSlotImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: projection.viewLength(size.width),
                           height: projection.viewLength(size.height))
                    .allowsHitTesting(false)
                    .position(projection.viewPoint(slotPosition))
            }
        }
    }
}
