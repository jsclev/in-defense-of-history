// swift-tools-version: 6.2
import PackageDescription

// Exercises the actual editor format code without launching the app or loading
// the user's database. Engine sources supply the shared draft/blueprint types.
let package = Package(
    name: "LevelEditorFormats",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "LevelEditorFormats", path: ".",
                exclude: [
                    "AGENTS.md",
                    "Db",
                    "Images",
                    "InDefenseOfHistory.xcodeproj",
                    "Liberty Line",
                    "Simulator",
                    "Tests",
                    "Tools",
                    "Versioning",
                    "GameName.xcconfig",
                    "in_defense_of_history.sqlite",
                    "build",
                    "Engine/Debug/DebugLayoutGuidesView.swift",
                    "LevelEditor/PlaytestView.swift",
                    "LevelEditor/PathArtist.swift",
                    "LevelEditor/BrushInputView.swift",
                    "LevelEditor/LevelEditorApp.swift",
                    "LevelEditor/Assets.xcassets",
                    "LevelEditor/InspectorView.swift",
                    "LevelEditor/EditorLayers.swift",
                    "LevelEditor/HeroPlacementIcon.swift",
                    "LevelEditor/TowerSlotImage.swift",
                    "LevelEditor/EditorContent.swift",
                    "LevelEditor/PlaytestCanvas.swift",
                    "LevelEditor/EditorView.swift",
                    "LevelEditor/EditorCanvas.swift",
                    "LevelEditor/EditorGrid.swift",
                    "LevelEditor/Info.plist",
                    "LevelEditor/SimSession.swift"
                ],
                sources: [
                    "Engine",
                    "LevelEditor/MapDocument.swift",
                    "LevelEditor/EditorDocumentLifecycle.swift",
                    "LevelEditor/NativeMapFile.swift",
                    "LevelEditor/LevelGeoJSON.swift",
                    "LevelEditor/PathFlattening.swift",
                    "LevelEditor/GeoJSONExport.swift",
                    "LevelEditor/GeoJSONImport.swift",
                    "LevelEditor/GeoJSONFile.swift",
                    "LevelEditor/BrushStroke.swift",
                    "LevelEditor/EditorPaintGesture.swift",
                    "LevelEditor/Palette.swift",
                    "LevelEditor/PlatformSupport.swift",
                    "LevelEditor/SwiftExport.swift"
                ]),
        .testTarget(name: "LevelEditorFormatsTests", dependencies: ["LevelEditorFormats"],
                    path: "Tests/LevelEditorFormatsTests")
    ],
    swiftLanguageModes: [.v5]
)
