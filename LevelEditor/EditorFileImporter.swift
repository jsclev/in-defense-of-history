import SwiftUI
import UniformTypeIdentifiers

enum EditorImageImportTarget: Equatable {
    case background, overlay, guide
}

/// Image and GeoJSON actions share one native chooser.
struct EditorFileImportPresentation {
    enum Target: Equatable {
        case image(EditorImageImportTarget)
        case geoJSON

        var contentTypes: [UTType] {
            switch self {
            case .image: [.png, .jpeg, .tiff]
            case .geoJSON: [.geoJSON, .json]
            }
        }
    }

    var isPresented = false
    // SwiftUI dismisses the chooser before delivering its result. Keep the
    // target independent of isPresented so completion still knows its layer.
    private(set) var target: Target = .image(.background)

    mutating func present(_ target: Target) {
        self.target = target
        isPresented = true
    }
}

struct EditorFileImporter: ViewModifier {
    @Binding var presentation: EditorFileImportPresentation
    var onCompletion: (EditorFileImportPresentation.Target, Result<URL, Error>) -> Void

    func body(content: Content) -> some View {
        // File import/export presentation modifiers compete on the same
        // view. Give the importer its own host, separate from the exporter.
        content.background {
            Color.clear.fileImporter(isPresented: $presentation.isPresented,
                                     allowedContentTypes: presentation.target.contentTypes) { result in
                onCompletion(presentation.target, result)
            }
        }
    }
}
