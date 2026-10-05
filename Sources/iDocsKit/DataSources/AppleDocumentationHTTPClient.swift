import Foundation
import Logging
import iDocsTelemetry

public struct AppleDocumentationHTTPClient: Sendable {
    public static let standardRetryDelayNanoseconds: UInt64 = 1_000_000_000

    public static var defaultRetryDelayNanoseconds: UInt64 {
        if let env = ProcessInfo.processInfo.environment["IDOCS_RETRY_DELAY_NS"], let val = UInt64(env) {
            return val
        }
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil || env["SWIFT_TESTING_ENTRY_POINT"] != nil || env["XCInjectBundleInto"] != nil {
            return 0
        }
        return standardRetryDelayNanoseconds
    }

    private let logger = Logger(label: "com.snow.idocs-apple-http-client")
    public let session: any NetworkSession
    public let retryDelayNanoseconds: UInt64
    public let maxRetries: Int

    public init(
        session: any NetworkSession = URLSession.shared,
        retryDelayNanoseconds: UInt64? = nil,
        maxRetries: Int = 3
    ) {
        self.session = session
        self.retryDelayNanoseconds = retryDelayNanoseconds ?? Self.defaultRetryDelayNanoseconds
        self.maxRetries = maxRetries
    }

    public func fetchWithRetry(url: URL, maxRetries: Int? = nil) async throws -> Data {
        let retries = maxRetries ?? self.maxRetries
        var lastError: Error?
        var delayMultiplier: UInt64 = 1

        for attempt in 1...retries {
            do {
                var request = URLRequest(url: url)
                request.setValue(UserAgentPool.random(), forHTTPHeaderField: "User-Agent")
                let finalizedRequest = request

                let (data, response) = try await iDocsTelemetry.withHTTPClientSpan(
                    method: "GET",
                    url: url,
                    resendCount: attempt - 1
                ) {
                    let result = try await session.data(for: finalizedRequest)
                    if let http = result.1 as? HTTPURLResponse {
                        iDocsTelemetry.recordHTTPResponse(statusCode: http.statusCode)
                    }
                    return result
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        return data
                    } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                        lastError = iDocsError.httpError(statusCode: httpResponse.statusCode)
                        logger.warning("Attempt \(attempt) failed with status code \(httpResponse.statusCode). Retrying...")
                    } else {
                        throw iDocsError.httpError(statusCode: httpResponse.statusCode)
                    }
                } else {
                    lastError = iDocsError.invalidResponse
                }
            } catch {
                let isCancelled = Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
                if isCancelled {
                    throw CancellationError()
                }
                lastError = error
                logger.error("Attempt \(attempt) failed with error: \(error.localizedDescription)")
                if !shouldRetry(after: error) {
                    throw error
                }
            }

            if attempt < retries {
                let delay = delayMultiplier * retryDelayNanoseconds
                if delay > 0 {
                    try await Task.sleep(nanoseconds: delay)
                }
                delayMultiplier *= 2
            }
        }

        throw lastError ?? iDocsError.maxRetriesReached
    }

    public func shouldRetry(after error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
            return false
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .resourceUnavailable,
                 .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        guard let idocsError = error as? iDocsError else {
            return true
        }

        switch idocsError {
        case .httpError(let statusCode):
            return statusCode == 403 || statusCode == 429
        case .maxRetriesReached:
            return true
        default:
            return false
        }
    }

    public func fetchData(for path: String) async throws -> Data {
        guard let url = URLHelpers.dataURL(for: path) else {
            throw iDocsError.invalidURL
        }
        return try await fetchWithRetry(url: url)
    }

    public func fetchTechnologiesData() async throws -> Data {
        guard let url = URLHelpers.technologiesURL() else {
            throw iDocsError.invalidURL
        }
        return try await fetchWithRetry(url: url)
    }

    public func fetchSearchData(query: String) async throws -> Data? {
        guard let url = URLHelpers.searchURL(query: query) else {
            return nil
        }
        return try await fetchWithRetry(url: url)
    }
}
