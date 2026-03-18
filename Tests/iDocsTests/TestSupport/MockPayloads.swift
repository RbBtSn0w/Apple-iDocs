import Foundation

enum MockPayloads {
    static let searchJSON = """
    {
        "references": {
            "doc://com.apple.documentation/documentation/SwiftUI/View": {
                "title": "View",
                "kind": "protocol",
                "url": "/documentation/swiftui/view",
                "abstract": [
                    {
                        "type": "text",
                        "text": "A type that represents part of your user interface."
                    }
                ]
            },
            "example-image.png": {
                "type": "image",
                "identifier": "example-image.png"
            }
        }
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

    static let sosumiSearchJSON = """
    {
        "query": "View",
        "results": [
            {
                "title": "View",
                "url": "https://developer.apple.com/documentation/swiftui/view",
                "description": "A type that represents part of your user interface.",
                "type": "documentation"
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
