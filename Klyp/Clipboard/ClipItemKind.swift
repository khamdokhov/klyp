import Foundation

enum ClipItemKind: String, Codable, CaseIterable {
    case text
    case richText
    case link
    case color
    case image
    case file
}
