import SwiftUI
import UIKit

struct TowerSelectionLabel: View {
    let details: TowerMenuDetails
    let button: CGRect
    let safeBounds: CGRect
    var obstacles: [CGRect] = []
    @Environment(\.sizeCategory) private var sizeCategory

    var body: some View {
        let text = TowerLabelText.attributedText(details, category: sizeCategory)
        let measuringLabel = TowerLabelText.label(text)
        if let placement = TowerLabelPlacement.resolve(button: button, safeBounds: safeBounds,
            avoiding: obstacles, measure: { width in
                ceil(measuringLabel.sizeThatFits(CGSize(width: width - 24,
                    height: .greatestFiniteMagnitude)).height) + 24
            }) {
            ScrollView(.vertical) {
                TowerLabelText(text: text)
                    .frame(width: placement.frame.width - 24,
                           height: placement.contentHeight - 24)
                    .padding(12)
            }
            .scrollDisabled(!placement.needsScrolling)
            .frame(width: placement.frame.width, height: placement.frame.height)
            .background(Color(red: 0.055, green: 0.085, blue: 0.11),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(red: 0.75, green: 0.57, blue: 0.29), lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
            .contentShape(Rectangle())
            .onTapGesture {} // Reading the label must not dismiss the selection.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(details.name)
            .accessibilityValue(details.description)
            .accessibilityIdentifier("tower-selection-label")
            .position(x: placement.frame.midX, y: placement.frame.midY)
        }
    }
}

/// Measurement and rendering use exactly the same native text engine, fonts,
/// paragraph spacing and wrapping. No line-count or character-count estimates.
private struct TowerLabelText: UIViewRepresentable {
    let text: NSAttributedString

    static func label(_ text: NSAttributedString) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.attributedText = text
        return label
    }

    func makeUIView(context: Context) -> UILabel { Self.label(text) }
    func updateUIView(_ uiView: UILabel, context: Context) { uiView.attributedText = text }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: proposal.height ?? ceil(height))
    }

    static func attributedText(_ details: TowerMenuDetails,
                               category: ContentSizeCategory) -> NSAttributedString {
        let categories: [ContentSizeCategory: UIContentSizeCategory] = [
            .extraSmall: .extraSmall, .small: .small, .medium: .medium, .large: .large,
            .extraLarge: .extraLarge, .extraExtraLarge: .extraExtraLarge,
            .extraExtraExtraLarge: .extraExtraExtraLarge,
            .accessibilityMedium: .accessibilityMedium, .accessibilityLarge: .accessibilityLarge,
            .accessibilityExtraLarge: .accessibilityExtraLarge,
            .accessibilityExtraExtraLarge: .accessibilityExtraExtraLarge,
            .accessibilityExtraExtraExtraLarge: .accessibilityExtraExtraExtraLarge
        ]
        let traits = UITraitCollection(preferredContentSizeCategory: categories[category] ?? .large)
        // Apple WWDC24 "Design advanced games for Apple platforms": aim for
        // 17 pt or larger body/callout text on iPhone and iPad. These are screen
        // points, independent of map scale; smaller text settings keep this floor.
        let bodySize = max(17, UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: traits))
        let titleSize = max(20, UIFontMetrics(forTextStyle: .title3).scaledValue(for: 20, compatibleWith: traits))
        let titleBase = UIFont.systemFont(ofSize: titleSize, weight: .bold)
        let titleFont = UIFont(descriptor: titleBase.fontDescriptor.withDesign(.serif) ?? titleBase.fontDescriptor,
                               size: titleSize)
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.paragraphSpacing = 6
        titleParagraph.lineBreakMode = .byWordWrapping
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 2
        bodyParagraph.lineBreakMode = .byWordWrapping
        let text = NSMutableAttributedString(string: details.name + "\n", attributes: [
            .font: titleFont, .foregroundColor: UIColor(red: 1, green: 0.82, blue: 0.39, alpha: 1),
            .paragraphStyle: titleParagraph
        ])
        text.append(NSAttributedString(string: details.description, attributes: [
            .font: UIFont.systemFont(ofSize: bodySize),
            .foregroundColor: UIColor(red: 0.96, green: 0.94, blue: 0.87, alpha: 1),
            .paragraphStyle: bodyParagraph
        ]))
        return text
    }
}
