import Foundation
import Logging
import iDocsApp
import iDocsAdapter

@main
struct Main {
    static func main() {
        let appLogger = Logger(label: "com.snow.idocs-main")
        CLIEnvironment.loggerFactory = { appLogger }
        CLIEnvironment.configFactory = { DocumentationConfig.cliDefault() }
        CLIEnvironment.serviceFactory = {
            try DefaultDocumentationAdapter(
                logger: StderrDocumentationLogger(underlying: appLogger)
            )
        }

        iDocsCLI.main()
    }
}
