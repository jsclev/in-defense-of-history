import Foundation

public class FileUtil {
    public static func copyFileFromBundleToDocuments(fileName: String, fileExtension: String) throws -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = getDocumentsURL()
        
        if let fileUrl = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            let targetFilePath = documentsDirectory.appendingPathComponent("\(fileName).\(fileExtension)").path

            if !fileManager.fileExists(atPath: targetFilePath) {
                do {
                    try fileManager.copyItem(atPath: fileUrl.path, toPath: targetFilePath)
                }
                catch let error {
                    throw GameError(message: "Unable to copy \"\(fileName).\(fileExtension)\" file to the \"Documents\" directory.  More details: \(error)")
                }
            }
        }
        else {
            throw GameError(message: "Attempted to copy the file \"\(fileName).\(fileExtension)\" to the sandboxed Documents folder at \"\(documentsDirectory.path)\", but the file is not in the bundle.")
        }
        
        return documentsDirectory.appendingPathComponent("\(fileName).\(fileExtension)")
    }
    
    public static func getDocumentsURL() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        return paths[0]
    }
}
