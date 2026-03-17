import Foundation
import iDocsAdapter

public enum CLIErrorPresenter {
    public static func message(for error: Error) -> String {
        guard let docError = error as? DocumentationError else {
            return "Error [INTERNAL]: \(error.localizedDescription)"
        }

        switch docError {
        case .notFound(let id):
            return "Error [NOT_FOUND]: Documentation for '\(id)' could not be found."
        case .networkError(let message):
            return "Error [NETWORK]: \(message)"
        case .parsingError(let reason):
            return "Error [PARSING]: \(reason)"
        case .unauthorized:
            return "Error [UNAUTHORIZED]: Access denied."
        case .invalidConfiguration(let message):
            return "Error [CONFIG]: \(message)"
        case .incompatibleVersion(let adapter, let core):
            return "Error [VERSION_MISMATCH]: Adapter \(adapter) is incompatible with Core \(core)."
        case .internalError(let message):
            return "Error [INTERNAL]: \(message)"
        }
    }
}
