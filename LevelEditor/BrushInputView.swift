#if os(iOS)
import SwiftUI
import UIKit

struct BrushInputView: UIViewRepresentable {
    var onBegan: (CGPoint, Double) -> Void
    var onMoved: (CGPoint, Double) -> Void
    var onEnded: () -> Void
    var onCancelled: () -> Void
    var onPinchBegan: () -> Void
    var onPinchChanged: (Double) -> Void
    var onPinchEnded: () -> Void

    func makeUIView(context: Context) -> BrushCaptureView {
        let view = BrushCaptureView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        view.handler = context.coordinator
        view.installPinch()
        return view
    }

    func updateUIView(_ view: BrushCaptureView, context: Context) {
        context.coordinator.onBegan = onBegan
        context.coordinator.onMoved = onMoved
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        context.coordinator.onPinchBegan = onPinchBegan
        context.coordinator.onPinchChanged = onPinchChanged
        context.coordinator.onPinchEnded = onPinchEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onBegan: onBegan, onMoved: onMoved,
                    onEnded: onEnded, onCancelled: onCancelled,
                    onPinchBegan: onPinchBegan, onPinchChanged: onPinchChanged,
                    onPinchEnded: onPinchEnded)
    }

    final class Coordinator {
        var onBegan: (CGPoint, Double) -> Void
        var onMoved: (CGPoint, Double) -> Void
        var onEnded: () -> Void
        var onCancelled: () -> Void
        var onPinchBegan: () -> Void
        var onPinchChanged: (Double) -> Void
        var onPinchEnded: () -> Void

        init(onBegan: @escaping (CGPoint, Double) -> Void,
             onMoved: @escaping (CGPoint, Double) -> Void,
             onEnded: @escaping () -> Void,
             onCancelled: @escaping () -> Void,
             onPinchBegan: @escaping () -> Void,
             onPinchChanged: @escaping (Double) -> Void,
             onPinchEnded: @escaping () -> Void) {
            self.onBegan = onBegan
            self.onMoved = onMoved
            self.onEnded = onEnded
            self.onCancelled = onCancelled
            self.onPinchBegan = onPinchBegan
            self.onPinchChanged = onPinchChanged
            self.onPinchEnded = onPinchEnded
        }
    }

    final class BrushCaptureView: UIView {
        var handler: Coordinator?

        private weak var activeTouch: UITouch?

        func installPinch() {
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
            pinch.delegate = self
            addGestureRecognizer(pinch)
        }

        private func pressure(_ touch: UITouch) -> Double {
            guard touch.type == .pencil, touch.maximumPossibleForce > 0 else { return 0 }
            return max(0, min(1, Double(touch.force / touch.maximumPossibleForce)))
        }

        private func begin(_ touch: UITouch) {
            activeTouch = touch
            handler?.onBegan(touch.location(in: self), pressure(touch))
        }

        private func cancelStroke() {
            guard activeTouch != nil else { return }
            activeTouch = nil
            handler?.onCancelled()
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            if let active = activeTouch, active.type != .pencil,
               let pencil = touches.first(where: { $0.type == .pencil }) {
                cancelStroke()
                begin(pencil)
                return
            }

            if (event?.touches(for: self)?.count ?? touches.count) > 1 {
                cancelStroke()
                return
            }

            guard activeTouch == nil, let touch = touches.first else { return }
            begin(touch)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = activeTouch, touches.contains(touch) else { return }
            for coalesced in event?.coalescedTouches(for: touch) ?? [touch] {
                handler?.onMoved(coalesced.location(in: self), pressure(coalesced))
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = activeTouch, touches.contains(touch) else { return }
            activeTouch = nil
            handler?.onEnded()
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = activeTouch, touches.contains(touch) else { return }
            cancelStroke()
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                cancelStroke()
                handler?.onPinchBegan()
            case .changed:
                handler?.onPinchChanged(Double(recognizer.scale))
            case .ended, .cancelled, .failed:
                handler?.onPinchEnded()
            default:
                break
            }
        }
    }
}

extension BrushInputView.BrushCaptureView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
#endif
