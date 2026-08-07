import Foundation
import os

public class LogUtility {
//    private let publicGameState: PublicGameState
//    private let player: Player?
//    
//    public init(publicGameState: PublicGameState) {
//        self.publicGameState = publicGameState
//        self.player = nil
//    }
//    
//    public init(publicGameState: PublicGameState, player: Player) {
//        self.publicGameState = publicGameState
//        self.player = player
//    }
    
    public static func getLogger(_ primary: LogCategory, _ secondary: AnyClass) -> Logger {
        return Logger(subsystem: Constants.appIdentifier,
                      category: "\(primary) - \(String(describing: secondary))")
    }
    
    public static func getSignposter(_ primary: LogCategory, _ secondary: AnyClass) -> OSSignposter {
        return OSSignposter(subsystem: Constants.appIdentifier,
                            category: "\(primary) - \(String(describing: secondary))")
    }
    
//    public static func getPrepend(civilization: Civilization) -> String {
//        var logPrepend = "⚫"
//
//        switch civilization.colorType {
//        case .Blue: logPrepend = "🔵"
//        case .Green: logPrepend = "🟢"
//        case .Orange: logPrepend = "🟠"
//        case .Purple: logPrepend = "🟣"
//        case .Red: logPrepend = "🔴"
//        case .White: logPrepend = "⚪"
//        case .Yellow: logPrepend = "🟡"
//        }
//
//        return logPrepend
//    }
    
    public var prepend: String {
        return ""
//        if let player = player {
//            return "\(player.publicProfile.logPrepend) Turn \(self.publicGameState.currentTurn.value.ordinal):"
//        }
//        
//        return "Turn \(self.publicGameState.currentTurn.value.ordinal):"
    }
}
