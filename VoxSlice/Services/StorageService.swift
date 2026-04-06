import Foundation

@Observable
final class StorageService {
    private let fileManager = FileManager.default
    private let defaults = UserDefaults.standard

    /// The user-configured output folder path. Defaults to ~/Documents/VoxSlice per D-09.
    var outputFolderPath: String {
        didSet {
            defaults.set(outputFolderPath, forKey: AppConstants.outputFolderKey)
            createDirectoryStructure()
        }
    }

    init() {
        self.outputFolderPath = defaults.string(forKey: AppConstants.outputFolderKey)
            ?? NSString(string: AppConstants.defaultOutputPath).expandingTildeInPath
        createDirectoryStructure()
    }

    /// Creates the full directory structure under the output folder per D-10:
    /// recordings/, transcripts/, analysis/, config/
    func createDirectoryStructure() {
        let baseURL = URL(fileURLWithPath: outputFolderPath)
        let subdirectories = [
            AppConstants.recordingsDir,
            AppConstants.transcriptsDir,
            AppConstants.analysisDir,
            AppConstants.configDir
        ]
        for dir in subdirectories {
            let dirURL = baseURL.appendingPathComponent(dir)
            try? fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }
    }

    /// Returns the URL for a specific subdirectory
    func directoryURL(for subdirectory: String) -> URL {
        URL(fileURLWithPath: outputFolderPath).appendingPathComponent(subdirectory)
    }
}
