import Foundation

public class GameError: Error, CustomStringConvertible {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
    
    public var description : String {
        message
    }

}
