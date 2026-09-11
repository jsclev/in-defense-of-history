import SwiftUI

struct LevelTowerSlotsView: View {
    let debugMode: Bool
    let slotPositions: [CGPoint]
    let occupiedSlotIndices: Set<Int>
    let size: CGSize
    let projection: LevelMapProjection
    
    var body: some View {
        ForEach(Array(slotPositions.enumerated()), id: \.offset) { index, slotPosition in
            let imageName = occupiedSlotIndices.contains(index)
                ? "tower_slot_field" : "tower_slot_available"
            if debugMode {
                ZStack {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: projection.viewLength(size.width),
                               height: projection.viewLength(size.height))
                        .allowsHitTesting(false)
                    
                    Text(String(index))
                        .font(.system(size: Typography.size(projection.viewLength(size.height) * 0.6)))
                        .bold()
                        .foregroundColor(.black)
                        .allowsHitTesting(false)
                }.position(projection.viewPoint(slotPosition))
            }
            else {
                Image(imageName)
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
