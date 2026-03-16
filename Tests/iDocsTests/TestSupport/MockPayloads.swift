import Foundation

enum MockPayloads {
    static let searchJSON = """
    {
        "results": [
            {
                "title": "View",
                "type": "protocol",
                "url": "/documentation/swiftui/view",
                "abstract": "A type that represents part of your user interface."
            }
        ]
    }
    """.data(using: .utf8)!

    static let technologiesJSON = """
    {
        "technologies": [
            {
                "name": "SwiftUI",
                "url": "/documentation/swiftui",
                "kind": "framework"
            }
        ]
    }
    """.data(using: .utf8)!

    static let externalDocCJSON = """
    {
        "identifier": "doc://com.example/documentation/example",
        "metadata": {
            "title": "Example"
        }
    }
    """.data(using: .utf8)!

    static func httpResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
