import Foundation

extension String {
    var isOpaqueMissQuery: Bool {
        guard !self.contains(where: \.isWhitespace) else { return false }
        guard self.count >= 16 else { return false }
        guard let first = self.first, first.isLowercase else { return false }
        guard self.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil else { return false }
        return self.lowercased() == self
    }
}
