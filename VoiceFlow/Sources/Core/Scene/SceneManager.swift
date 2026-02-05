import Foundation

/// Manager for scene profile operations including import/export
final class SceneManager {
    static let shared = SceneManager()

    private init() {}

    /// Export a scene profile to a file
    /// - Parameters:
    ///   - sceneType: The scene type to export
    ///   - toPath: Destination file path (should end with .vfscene)
    /// - Returns: True if export succeeded, false otherwise
    func exportScene(sceneType: SceneType, toPath: String) -> Bool {
        let profile = SceneProfile.defaultProfile(for: sceneType)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(profile)
            let url = URL(fileURLWithPath: toPath)
            try data.write(to: url, options: .atomic)
            NSLog("[SceneManager] Successfully exported \(sceneType.rawValue) scene to \(toPath)")
            return true
        } catch {
            NSLog("[SceneManager] Failed to export scene: \(error.localizedDescription)")
            return false
        }
    }

    /// Import a scene profile from a file
    /// - Parameter fromPath: Source file path (.vfscene file)
    /// - Returns: Result containing the imported SceneProfile or an error
    func importScene(fromPath: String) -> Result<SceneProfile, Error> {
        let url = URL(fileURLWithPath: fromPath)

        do {
            let data = try Data(contentsOf: url)

            // Validate JSON structure before decoding
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(SceneImportError.invalidJSON)
            }

            // Validate required fields
            guard json["sceneType"] != nil else {
                return .failure(SceneImportError.missingRequiredField("sceneType"))
            }
            guard json["glossary"] != nil else {
                return .failure(SceneImportError.missingRequiredField("glossary"))
            }
            guard json["enablePolish"] != nil else {
                return .failure(SceneImportError.missingRequiredField("enablePolish"))
            }
            guard json["polishStyle"] != nil else {
                return .failure(SceneImportError.missingRequiredField("polishStyle"))
            }

            // Decode the validated JSON
            let decoder = JSONDecoder()
            let profile = try decoder.decode(SceneProfile.self, from: data)

            NSLog("[SceneManager] Successfully imported scene: \(profile.sceneType.rawValue)")
            return .success(profile)

        } catch let error as DecodingError {
            NSLog("[SceneManager] Failed to decode scene profile: \(error)")
            return .failure(SceneImportError.decodingFailed(error))
        } catch {
            NSLog("[SceneManager] Failed to import scene: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}

/// Errors that can occur during scene import
enum SceneImportError: LocalizedError {
    case invalidJSON
    case missingRequiredField(String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The file does not contain valid JSON data"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .decodingFailed(let error):
            return "Failed to decode scene profile: \(error.localizedDescription)"
        }
    }
}
