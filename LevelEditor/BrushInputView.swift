#if os(iOS)
import SwiftUI
import UIKit

final class BrushStrokeRecognizer: UIGestureRecognizer {
    var onBegan: ((CGPoint, Double) -> Void)?
    var onMoved: ((CGPoint, Double) -> Void)?
    var onEnded: (() -> Void)?
    var onCancelled: (() -> Void)?

    private weak var tracked: UITouch?

    private func pressure(_ touch: UITouch) -> Double {
        guard touch.type == .pencil, touch.maximumPossibleForce > 0 else { return 0 }
        return max(0, min(1, Double(touch.force / touch.maximumPossibleForce)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let current = tracked, current.type != .pencil,
           let pencil = touches.first(where: { $0.type == .pencil }) {
            onCancelled?()
            tracked = pencil
            onBegan?(pencil.location(in: view), pressure(pencil))
            return
        }
        if tracked == nil, let touch = touches.first, touches.count == 1 {
            tracked = touch
            state = .began
            onBegan?(touch.location(in: view), pressure(touch))
        } else if tracked?.type != .pencil {
            tracked = nil
            onCancelled?()
            state = .cancelled
        } else {
            for touch in touches where touch !== tracked {
                ignore(touch, for: event)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        for coalesced in event.coalescedTouches(for: touch) ?? [touch] {
            onMoved?(coalesced.location(in: view), pressure(coalesced))
        }
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        tracked = nil
        onEnded?()
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = tracked, touches.contains(touch) else { return }
        tracked = nil
        onCancelled?()
        state = .cancelled
    }

    override func reset() {
        tracked = nil
        super.reset()
    }
}

struct BrushInputView: UIViewRepresentable {
    var onBegan: (CGPoint, Double) -> Void
    var onMoved: (CGPoint, Double) -> Void
    var onEnded: () -> Void
    var onCancelled: () -> Void
    var onPinchBegan: () -> Void
    var onPinchChanged: (Double) -> Void
    var onPinchEnded: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let stroke = BrushStrokeRecognizer()
        stroke.delegate = context.coordinator
        view.addGestureRecognizer(stroke)
        context.coordinator.stroke = stroke

        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                             action: #selector(Coordinator.handlePinch))
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        context.coordinator.apply(self)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.apply(self)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var stroke: BrushStrokeRecognizer?
        var onPinchBegan: (() -> Void)?
        var onPinchChanged: ((Double) -> Void)?
        var onPinchEnded: (() -> Void)?

        func apply(_ view: BrushInputView) {
            stroke?.onBegan = view.onBegan
            stroke?.onMoved = view.onMoved
            stroke?.onEnded = view.onEnded
            stroke?.onCancelled = view.onCancelled
            onPinchBegan = view.onPinchBegan
            onPinchChanged = view.onPinchChanged
            onPinchEnded = view.onPinchEnded
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                onPinchBegan?()
            case .changed:
                onPinchChanged?(Double(recognizer.scale))
            case .ended, .cancelled, .failed:
                onPinchEnded?()
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            gestureRecognizer is UIPinchGestureRecognizer
                || other is UIPinchGestureRecognizer
        }
    }
}
#endif
