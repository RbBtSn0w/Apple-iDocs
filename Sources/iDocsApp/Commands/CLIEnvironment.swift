import Foundation
import iDocsAdapter

public enum CLIEnvironment {
    nonisolated(unsafe) public static var serviceFactory: () throws -> any DocumentationService = {
        try DefaultDocumentationAdapter()
    }

    nonisolated(unsafe) public static var configFactory: () -> DocumentationConfig = {
        DocumentationConfig.cliDefault()
    }

    nonisolated(unsafe) public static var writeStdout: @Sendable (String) -> Void = { message in
        print(message)
    }

    nonisolated(unsafe) public static var writeStderr: @Sendable (String) -> Void = { message in
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
