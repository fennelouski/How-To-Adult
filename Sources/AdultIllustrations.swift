import Foundation
import CryptoKit
import ImageIO

/// Optional artwork is bound to the exact catalog snapshot, never the live sidecar.
struct AdultIllustrations: Codable, Sendable {
    let schemaVersion: Int
    let revision: String
    let items: [GuideIllustration]

    static let maximumBytes = 4 * 1_024 * 1_024

    static func decode(_ data: Data, for catalog: AdultCatalog) throws -> AdultIllustrations {
        guard data.count <= maximumBytes else { throw CatalogError.tooLarge }
        let manifest = try JSONDecoder().decode(Self.self, from: data)
        guard manifest.schemaVersion == 1, manifest.revision == catalog.revision else { throw CatalogError.invalid }
        let articles = Dictionary(uniqueKeysWithValues: catalog.articles.map { ($0.id, $0) })
        var slots = Set<String>()
        for item in manifest.items {
            guard let article = articles[item.guideID],
                  item.stepID.isEmpty || article.steps.contains(where: { $0.id == item.stepID }),
                  slots.insert(item.guideID + "/" + item.stepID).inserted,
                  matches(item.assetSHA256, "^[a-f0-9]{64}$"),
                  validText(item.altText, maximum: 500),
                  item.caption.count <= 500,
                  !item.caption.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t" }),
                  validText(item.creator, maximum: 200),
                  validText(item.license, maximum: 300),
                  validText(item.provenance, maximum: 2_000) else { throw CatalogError.invalid }
        }
        return manifest
    }

    func illustration(guideID: String, stepID: String = "") -> GuideIllustration? {
        items.first { $0.guideID == guideID && $0.stepID == stepID }
    }

    static func manifestURL(catalogURL: URL, revision: String) -> URL? {
        // Match the backend's immutable revision route and prevent path traversal.
        guard matches(revision, "^[A-Za-z0-9][A-Za-z0-9._-]{0,95}$"),
              let base = apiBase(catalogURL) else { return nil }
        return base.appendingPathComponent("illustrations").appendingPathComponent(revision)
    }

    static func assetURL(catalogURL: URL, digest: String) -> URL? {
        guard matches(digest, "^[a-f0-9]{64}$"),
              let base = apiBase(catalogURL) else { return nil }
        return base.appendingPathComponent("assets").appendingPathComponent(digest)
    }

    private static func apiBase(_ url: URL) -> URL? {
        guard url.scheme == "https", url.host != nil, url.user == nil, url.password == nil,
              url.lastPathComponent == "catalog",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.query = nil
        components.fragment = nil
        return components.url?.deletingLastPathComponent()
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) == value.startIndex..<value.endIndex
    }

    private static func validText(_ value: String, maximum: Int) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.count <= maximum && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t" })
    }
}

struct GuideIllustration: Codable, Hashable, Sendable {
    let guideID: String
    let stepID: String
    let assetSHA256: String
    let altText: String
    let caption: String
    let creator: String
    let license: String
    let provenance: String
}

extension GuideIllustration {
    static let maximumImageBytes = 2 * 1_024 * 1_024
    var slot: String { guideID + "\u{0}" + stepID }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func image(_ data: Data, expectedDigest: String) throws -> CGImage {
        guard data.count <= maximumImageBytes, digest(data) == expectedDigest,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) as String? == "public.png",
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...4_096).contains(width), (1...4_096).contains(height),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 2_000,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw CatalogError.invalid }
        return image
    }
}

extension AdultIllustrations {
    func validate(for catalog: AdultCatalog) throws { _ = try Self.decode(JSONEncoder().encode(self), for: catalog) }
    static func catalogFingerprint(_ catalog: AdultCatalog) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return GuideIllustration.digest(try encoder.encode(catalog))
    }
}
typealias GuideIllustrationManifest = AdultIllustrations
