import Foundation
import iDocsAdapter

public enum CLIErrorPresenter {
    public static func category(for error: Error) -> CLIExitCategory {
        guard let docError = error as? DocumentationError else {
            return .internalError
        }

        switch docError {
        case .notFound:
            return .notFound
        case .networkError:
            return .network
        case .parsingError:
            return .parsing
        case .unauthorized:
            return .unauthorized
        case .invalidConfiguration, .invalidResolveIntent:
            return .config
        case .incompatibleVersion:
            return .versionMismatch
        case .internalError:
            return .internalError
        case .unsupportedSourceType:
            return .config
        case .aggregateFetchFailure:
            return .network
        }
    }

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
        case .invalidResolveIntent(let message):
            return "Error [CONFIG]: Invalid resolve intent: \(message)"
        case .incompatibleVersion(let adapter, let core):
            return "Error [VERSION_MISMATCH]: Adapter \(adapter) is incompatible with Core \(core)."
        case .internalError(let message):
            return "Error [INTERNAL]: \(message)"
        case .unsupportedSourceType(let id, let sourceKind, _):
            return "Error [CONFIG]: Unsupported Apple source type '\(sourceKind)' for '\(id)'."
        case .aggregateFetchFailure(_, let message, _):
            return "Error [NETWORK]: \(message)"
        }
    }
}
