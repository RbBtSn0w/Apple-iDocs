#!/usr/bin/env swift

import Foundation

struct ProbeConfig {
    var query = "SwiftUI view"
    var snippetLimit = 8
    var snippetRadius = 180
}

struct StoreProbe: Codable {
    let path: String
    let bytes: Int
    let queryHitCount: Int
    let allTermSnippetCount: Int
    let documentationPathHitCount: Int
    let snippets: [String]
}

struct CapabilitySummary: Codable {
    let documentationStoreFound: Bool
    let localTextSearchFeasible: Bool
    let localPathDiscoveryFeasible: Bool
    let localFullFetchFeasibleFromDemo: Bool
    let notes: [String]
}

struct ProbeReport: Codable {
    let query: String
    let documentationRoots: [String]
    let storeFiles: [StoreProbe]
    let capability: CapabilitySummary
}

let fileManager = FileManager.default
let home = fileManager.homeDirectoryForCurrentUser

var config = ProbeConfig()
var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let arg = args.removeFirst()
    switch arg {
    case "--query":
        if !args.isEmpty {
            config.query = args.removeFirst()
        }
    case "--snippet-limit":
        if let value = args.first, let parsed = Int(value) {
            config.snippetLimit = parsed
            args.removeFirst()
        }
    default:
        break
    }
}

let documentationRoots = [
    home.appendingPathComponent("Library/Developer/Xcode/DocumentationCache"),
    home.appendingPathComponent("Library/Developer/Xcode/DocumentationIndex")
]

let storeFiles = documentationRoots.flatMap { root in
    discoverFiles(
        under: root,
        maxDepth: 12,
        matching: { url in
            url.lastPathComponent == "store.db" || url.lastPathComponent == ".store.db"
        }
    )
}

let queryTerms = config.query
    .lowercased()
    .split { !$0.isLetter && !$0.isNumber }
    .map { Array(String($0).utf8) }
    .filter { !$0.isEmpty }

let storeReports = storeFiles.map { storeURL in
    probeStore(url: storeURL, terms: queryTerms, config: config)
}

let textHits = storeReports.reduce(0) { $0 + $1.allTermSnippetCount }
let pathHits = storeReports.reduce(0) { $0 + $1.documentationPathHitCount }
let capability = CapabilitySummary(
    documentationStoreFound: !storeReports.isEmpty,
    localTextSearchFeasible: textHits > 0,
    localPathDiscoveryFeasible: pathHits > 0,
    localFullFetchFeasibleFromDemo: false,
    notes: capabilityNotes(storeReports: storeReports)
)

let report = ProbeReport(
    query: config.query,
    documentationRoots: documentationRoots.map(\.path),
    storeFiles: storeReports,
    capability: capability
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(report)
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data("\n".utf8))

func discoverFiles(
    under root: URL,
    maxDepth: Int,
    matching predicate: (URL) -> Bool
) -> [URL] {
    guard fileManager.fileExists(atPath: root.path) else { return [] }
    let rootDepth = root.pathComponents.count
    guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: []
    ) else {
        return []
    }

    var results: [URL] = []
    for case let url as URL in enumerator {
        let depth = url.pathComponents.count - rootDepth
        if depth > maxDepth {
            enumerator.skipDescendants()
            continue
        }

        guard predicate(url) else { continue }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        if values?.isRegularFile == true {
            results.append(url)
        }
    }
    return results.sorted { $0.path < $1.path }
}

func probeStore(url: URL, terms: [[UInt8]], config: ProbeConfig) -> StoreProbe {
    guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
        return StoreProbe(
            path: url.path,
            bytes: 0,
            queryHitCount: 0,
            allTermSnippetCount: 0,
            documentationPathHitCount: 0,
            snippets: []
        )
    }

    let firstTerm = terms.first ?? []
    let firstTermHits = firstTerm.isEmpty ? [] : findOccurrences(of: firstTerm, in: data)
    let documentationPathHits = findOccurrences(of: Array("/documentation/".utf8), in: data).count
    var snippets: [String] = []

    for offset in firstTermHits {
        let snippet = sanitizedSnippet(data: data, center: offset, radius: config.snippetRadius)
        let lower = snippet.lowercased()
        let containsAllTerms = terms.allSatisfy { term in
            guard let termString = String(bytes: term, encoding: .utf8) else { return false }
            return lower.contains(termString)
        }
        guard containsAllTerms else { continue }
        if !snippets.contains(snippet) {
            snippets.append(snippet)
        }
        if snippets.count >= config.snippetLimit {
            break
        }
    }

    return StoreProbe(
        path: url.path,
        bytes: data.count,
        queryHitCount: firstTermHits.count,
        allTermSnippetCount: snippets.count,
        documentationPathHitCount: documentationPathHits,
        snippets: snippets
    )
}

func findOccurrences(of needle: [UInt8], in data: Data) -> [Int] {
    guard !needle.isEmpty, data.count >= needle.count else { return [] }
    let loweredNeedle = needle.map(asciiLowercase)
    var offsets: [Int] = []
    var index = 0
    while index <= data.count - loweredNeedle.count {
        var matched = true
        for j in 0..<loweredNeedle.count where asciiLowercase(data[index + j]) != loweredNeedle[j] {
            matched = false
            break
        }
        if matched {
            offsets.append(index)
            index += loweredNeedle.count
        } else {
            index += 1
        }
    }
    return offsets
}

func sanitizedSnippet(data: Data, center: Int, radius: Int) -> String {
    let start = max(0, center - radius)
    let end = min(data.count, center + radius)
    guard start < end else { return "" }
    var scalarBytes: [UInt8] = []
    scalarBytes.reserveCapacity(end - start)

    for index in start..<end {
        let byte = data[index]
        switch byte {
        case 32...126:
            scalarBytes.append(byte)
        case 9, 10, 13:
            scalarBytes.append(32)
        default:
            scalarBytes.append(32)
        }
    }

    let raw = String(bytes: scalarBytes, encoding: .utf8) ?? ""
    return raw
        .split { $0.isWhitespace }
        .joined(separator: " ")
}

func asciiLowercase(_ byte: UInt8) -> UInt8 {
    if byte >= 65 && byte <= 90 {
        return byte + 32
    }
    return byte
}

func capabilityNotes(storeReports: [StoreProbe]) -> [String] {
    var notes: [String] = []
    if storeReports.isEmpty {
        notes.append("No Xcode documentation store.db files were found.")
    } else {
        notes.append("Xcode documentation store files are present and readable.")
    }

    if storeReports.contains(where: { $0.allTermSnippetCount > 0 }) {
        notes.append("The store contains extractable text snippets for the query.")
    } else {
        notes.append("The demo did not extract all query terms from the store; this can be a query miss or an unsupported encoding/layout.")
    }

    if storeReports.contains(where: { $0.documentationPathHitCount > 0 }) {
        notes.append("The store exposes /documentation/ path strings directly.")
    } else {
        notes.append("The demo did not find /documentation/ path strings directly, so path recovery may require decoding Xcode's private record format.")
    }

    notes.append("Full local fetch is not proven by this demo; it only proves local text/snippet extraction and direct path-string discovery.")
    return notes
}
