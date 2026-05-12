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

    static let emptySearchJSON = """
    {
        "references": {}
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

    static let technologiesModernJSON = """
    {
      "schemaVersion": { "major": 0, "minor": 3, "patch": 0 },
      "sections": [
        {
          "kind": "technologies",
          "groups": [
            {
              "technologies": [
                {
                  "title": "SwiftUI",
                  "tags": ["Frameworks", "UI"],
                  "destination": {
                    "type": "reference",
                    "identifier": "doc://com.apple.documentation/documentation/swiftui"
                  }
                }
              ]
            }
          ]
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

    static let emptySosumiSearchJSON = """
    {
        "query": "Empty",
        "results": []
    }
    """.data(using: .utf8)!

    static let mixedSosumiSearchJSON = """
    {
        "query": "Xcode Cloud TestFlight App Store Connect",
        "results": [
            {
                "title": "Creating a workflow that builds your app for distribution",
                "url": "https://developer.apple.com/documentation/xcode/creating-a-workflow-that-builds-your-app-for-distribution",
                "description": "Configure Xcode Cloud for distribution.",
                "type": "documentation"
            },
            {
                "title": "Upload builds",
                "url": "https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds",
                "description": "Upload builds to App Store Connect.",
                "type": "general"
            },
            {
                "title": "Meet Xcode Cloud",
                "url": "https://developer.apple.com/videos/play/wwdc2024/10123/",
                "description": "Video session.",
                "type": "general"
            },
            {
                "title": "Developer News",
                "url": "https://developer.apple.com/news/",
                "description": "Apple developer news.",
                "type": "general"
            },
            {
                "title": "App Store Connect API",
                "url": "https://developer.apple.com/app-store-connect/api",
                "description": "App Store Connect API overview.",
                "type": "general"
            }
        ]
    }
    """.data(using: .utf8)!

    static let appStoreConnectHelpHTML = """
    <!doctype html>
    <html>
      <head><title>Upload builds - App Store Connect Help</title></head>
      <body>
        <main>
          <h1>Upload builds</h1>
          <p>Upload builds to App Store Connect so you can distribute them with TestFlight or submit them for review.</p>
          <h2>Before you begin</h2>
          <p>Make sure your app record is configured.</p>
        </main>
      </body>
    </html>
    """.data(using: .utf8)!

    static func docCJSON(title: String, identifier: String, abstract: String) -> Data {
        """
        {
            "identifier": "\(identifier)",
            "metadata": {
                "title": "\(title)",
                "role": "symbol",
                "platforms": []
            },
            "abstract": [
                {
                    "type": "text",
                    "text": "\(abstract)"
                }
            ]
        }
        """.data(using: .utf8)!
    }

    static let externalDocCJSON = """
    {
        "identifier": "doc://com.example/documentation/example",
        "metadata": {
            "title": "Example"
        }
    }
    """.data(using: .utf8)!

    static func httpResponse(url: URL, statusCode: Int = 200, contentType: String = "application/json") -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        )!
    }
}
