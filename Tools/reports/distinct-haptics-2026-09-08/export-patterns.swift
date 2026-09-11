import Foundation
import CoreHaptics
import LevelEditorFormats

@main struct Export {
    static func main() throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        for cue in GameplayHapticPattern.allCases {
            let pattern = try cue.makePattern()
            let dictionary = try pattern.exportDictionary()
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: folder.appendingPathComponent("\(cue).ahap"))
        }
    }
}
