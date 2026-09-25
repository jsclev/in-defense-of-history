import SwiftUI

/// Persistent destinations make the three pages discoverable and directly selectable.
/// The binding also follows native page swipes; there is no automatic advancement.
struct EncyclopediaCarouselIndicators: View {
    @Binding var selection: Int
    let detailTitle: String
    let scale: CGFloat
    let ink: Color
    let accent: Color
    let identifierPrefix: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageKeys = ["demo", "details", "history"]
    private var titles: [String] { ["Demo", detailTitle, "History"] }

    var body: some View {
        HStack(spacing: 4 * scale) {
            ForEach(pageKeys.indices, id: \.self) { index in
                let selected = selection == index
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        selection = index
                    }
                } label: {
                    VStack(spacing: 3 * scale) {
                        Circle()
                            .fill(selected ? accent : .clear)
                            .overlay(Circle().strokeBorder(accent, lineWidth: 2 * scale))
                            .frame(width: 12 * scale, height: 12 * scale)
                            .accessibilityHidden(true)
                        Text(titles[index])
                            .font(.custom("Baskerville-Bold", size: 14 * scale))
                            .lineLimit(1)
                            .foregroundStyle(ink)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: max(TouchTarget.minimum, 44 * scale))
                    .background(selected ? accent.opacity(0.16) : .clear,
                                in: RoundedRectangle(cornerRadius: 7 * scale))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(index == 0 ? "Demonstration" : titles[index])
                .accessibilityValue("Page \(index + 1) of \(pageKeys.count)")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityIdentifier("\(identifierPrefix)-page-\(pageKeys[index])")
            }
        }
        .padding(.horizontal, 4 * scale)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifierPrefix)-carousel")
    }
}
