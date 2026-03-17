import Foundation
import iDocsApp

@main
struct Main {
    @available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
    static func main() {
        iDocsCLI.main()
    }
}
