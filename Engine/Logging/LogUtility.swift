import Foundation
import os

public class LogUtility {
    
    public static func getLogger(_ primary: LogCategory, _ secondary: AnyClass) -> Logger {
        return Logger(subsystem: Constants.appIdentifier,
                      category: "\(primary) - \(String(describing: secondary))")
    }
    
    public static func getSignposter(_ primary: LogCategory, _ secondary: AnyClass) -> OSSignposter {
        return OSSignposter(subsystem: Constants.appIdentifier,
                            category: "\(primary) - \(String(describing: secondary))")
    }

    public var prepend: String {
        return ""
    }
}
